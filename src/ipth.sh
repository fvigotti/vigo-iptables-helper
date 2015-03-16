#!/bin/bash

# BASICS -----------------------------------------------------------------------
# shell options: extended globbing
shopt -qs extglob

# global arrays: script metadata, user config, user commands
declare -Ax script config calltable
script[version]='1.1'
script[name]="${0##*/}"
script[pid]=$$
script[cmd_prefix]='cmd:'
script[verb_levels]='debug info status warning error critical fatal'
script[verb_override]=3
script[external_programs]='which iptables iptables-save iptables-restore tc sysctl readlink sed sort'

# USER CONFIG -----------------------------------------------------------------
# make sure this contains the path for "which", otherwise the script will abort
# in doubt type "which which"
config[which]='/usr/bin/which'

declare -Ax default_ipt_chains
default_ipt_chains[nat]='PREROUTING INPUT OUTPUT POSTROUTING'
default_ipt_chains[filter]='INPUT FORWARD OUTPUT'
default_ipt_chains[mangle]='PREROUTING FORWARD INPUT OUTPUT POSTROUTING'
default_ipt_chains[raw]='PREROUTING OUTPUT'
default_ipt_chains[security]='INPUT FORWARD OUTPUT'


ipth_check_version () {
REQUIRED_VERSION=$1
[ "${script[version]}" == "$REQUIRED_VERSION" ] || {
echo 'invalid version.. current = '"${script[version]}"' , required = '$REQUIRED_VERSION
return 1 ;
}
}

find_chain_exists(){
# search for a chain into a table
# return true (in bash is "return 0") if chain exists , false if not
local table_source=$1
local chain_to_search=$2
#local count_found=$(iptables  -L -n --line-number -t $table_source | awk '$2 ~ "^'${chain_to_search}'$" {print $2}' | wc -l )
local found=$(iptables  -L $chain_to_search -n -t $table_source 2>&1 >/dev/null && echo 'yes' || echo 'no' )
[ "$found" == "yes" ] && return 0 || return 1
}


find_jumpchain_rule_number (){
# search a jump chain rule number into another source-chain
# sample
# iptables -L FORWARD -n  --line-number  -t filter  | awk '$2 ~ "^DOCKER$"  {print  $1 }'
# @return 0 if not found
local table_source=$1
local chain_source=$2
local chain_to_search=$3
local retval=$(iptables  -L $chain_source -n  --line-number  -t $table_source | awk '$2 ~ "^'${chain_to_search}'$" {print $1}')
retval=${retval:-0}
echo $retval
}

delete_chain_references_in_default_chains (){
# search for chain references and delete them
# return amount of deleted references

local chain_to_search=$1
local table_name=$2
local COUNTER=0

for def_chain_name in ${default_ipt_chains[$table_name]}
  do
  found_rulenumber=$(find_jumpchain_rule_number $table_name $def_chain_name $chain_to_search)
  [ "$found_rulenumber" -gt "0" ] && {
      echo 'found/deleting rule on : '$table_name' > '$def_chain_name' rule n.: '$found_rulenumber  >&2
      COUNTER=$[$COUNTER +1]
      iptables -t $table_name -D $def_chain_name $found_rulenumber
  }
  #echo "value: ${default_ipt_chains[$i]}"
  done
echo $COUNTER
}

delete_chain_references_in_all_tables (){
# sesarch for chain references and then delete them
# in all default table and chains
# return amount of deleted references
local chain_to_search=$1
local COUNTER=0

for table_name in "${!default_ipt_chains[@]}"
do
  echo "entering table name : $table_name" >&2
  found=$(delete_chain_references_in_default_chains $chain_to_search "${default_ipt_chains[$table_name]}")
  COUNTER=$[$found +1]
done
echo $COUNTER
}

get_last_rule_number(){
# @return the number of the last rule in a chain, 0 if no rules are present
local table_source=$1
local chain_source=$2
local retval=$(iptables -L $chain_source  -n  --line-number  -t $table_source | egrep  "^[0-9]+" | tail -1 |awk '{ print $1 }')
retval=${retval:-0}
echo $retval
}


get_chain_references_count() {
# @return the count of references to a chain
local table_name=$1
local chain_to_search=$2
local retval=$(iptables -L -n -v -t $table_name  | grep 'Chain '$chain_to_search | sed -e 's/^[^\(]*(\([0-9]*\).*/\1/g')
retval=${retval:-0}
echo $retval
}


recursive_delete_chain() {
# performed actions:
# - delete references to custom chain,
# - delete custom chains
    declare -A creator
    creator[table]=$1
    creator[custom_chain_name]=$2

    # CLEAR PREVIOUS STATUS > delete references to chain and delete chain
    echo '>>> deleting references for chain : '$creator[custom_chain_name] >&2

    deleted_items=$(delete_chain_references_in_default_chains "${creator[custom_chain_name]}" "${creator[table]}")
    echo '>>> deleting chain : '"${creator[custom_chain_name]}" >&2
    ## flush
    /sbin/iptables -t "${creator[table]}" -F "${creator[custom_chain_name]}"
    ## delete
    /sbin/iptables -t "${creator[table]}" -X "${creator[custom_chain_name]}"
}

create_chain() {
# create the required chain
    declare -A creator
    creator[table]=$1
    creator[custom_chain_name]=$2

    /sbin/iptables -t "${creator[table]}" -N "${creator[custom_chain_name]}"
    [ "$?" == "0" ] || {
        echo '[FATAL] error during chain creation ! '"${creator[table]}"' '"${creator[custom_chain_name]}" >&2
        exit 1
    }
    return 0
}


autogenerate_custom_chain_name() {
    declare -A creator
    creator[table]=$1
    creator[chain]=$2 # chain name (if position is manual) , or destination chain
    creator[position]=$3 # first , last ( default) , manual
    local retval='v_'"${creator[position]}"'_'"${creator[table]}"'_'"${creator[chain]}"
    echo $retval
}

create_jump_rule(){
# inject chain jump on first or last position in given parent chain
    declare -A creator
    creator[table]=$1
    creator[chain_src]=$2 # source chain where to insert the jump rule
    creator[chain_dst]=$3 # chain to jump into
    creator[position]=$4 # first , last ( default)
    local JUMP_ADDITIONAL_PARAMS=$5 # additional matches for the jump rule

    ## custom chain positioning
    local RULE_position=""
    local RULE_binding_action="A" # append
    [ "${creator[position]}" == "first" ] && {
        RULE_position="1"
        RULE_binding_action="I" # insert
    }

    /sbin/iptables -t "${creator[table]}" -"${RULE_binding_action}" "${creator[chain_src]}" $RULE_position $JUMP_ADDITIONAL_PARAMS -j "${creator[chain_dst]}"

    [ "$?" == "0" ] || {
        echo '[FATAL] error during jump insertion ! > '"${creator[table]}"' -'"${RULE_binding_action}"' '"${creator[chain_src]}"' '$RULE_position' '$JUMP_ADDITIONAL_PARAMS' -j '"${creator[chain_dst]}" >&2
        exit 1
    }
    return 0
}



autocreate_autopositioned_chain() {
# create chain autopositioned & autnominated on top/bottom of another chain
# return the name of the chain created or '' if the chain has been only flushed & deleted

    declare -A creator

    # HEADER
    creator[enabled]=$1 # 0 = false , 1 = true
    creator[table]=$2 # iptables destination table
    creator[chain]=$3 # destination chain
    creator[position]=$4 # first , last ( default)

    # PARAM VALIDATION
    [ "${creator[position]}" != "first" ] && [ "${creator[position]}" != "last" ] && {
        echo '[FATAL] invalid chain positioning '"${creator[position]}" >&2
        exit 1
    }

    # GENERATE CHAIN NAME
    local GENERATED_CHAIN_NAME=$(autogenerate_custom_chain_name "${creator[table]}" "${creator[chain]}" "${creator[position]}")
    echo 'generated chain name : '$GENERATED_CHAIN_NAME >&2

    # FLUSH PREVIOUS VERSION OF THE CHAIN
    if find_chain_exists "${creator[table]}" $GENERATED_CHAIN_NAME ; then
        echo 'previous version of the chain is going to be flushed : '$GENERATED_CHAIN_NAME >&2
        recursive_delete_chain "${creator[table]}" $GENERATED_CHAIN_NAME
    fi


    if [ "${creator[enabled]}" -eq "1" ] ; then

        create_chain "${creator[table]}" $GENERATED_CHAIN_NAME
        create_jump_rule "${creator[table]}" "${creator[chain]}" $GENERATED_CHAIN_NAME "${creator[position]}"

        echo 'chain '$GENERATED_CHAIN_NAME ' is now enabled' >&2
        echo $GENERATED_CHAIN_NAME
    else
        echo 'chain '$GENERATED_CHAIN_NAME ' will be disabled' >&2
        echo ''
    fi


}

