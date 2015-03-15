#!/bin/bash

# BASICS -----------------------------------------------------------------------
# shell options: extended globbing
shopt -qs extglob

# global arrays: script metadata, user config, user commands
declare -Ax script config calltable
script[version]='1.0'
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

find_chain_exists(){
# search for a chain into a table
# return true (in bash is "return 0") if chain exists , false if not
local table_source=$1
local chain_to_search=$2
local count_found=$(iptables  -L -n --line-number -t $table_source | awk '$2 ~ "^'${chain_to_search}'$" {print $2}' | wc -l )
count_found=${count_found:-0}
[ "$count_found" -eq "1" ] && return 0 || return 1
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
local retval=$(iptables -L -n -v -t nat  | grep 'Chain '$table_name | sed -e 's/^[^\(]*(\([0-9]*\).*/\1/g')
retval=${retval:-0}
echo $retval
}

create_or_flush_initial_jump_chain (){
# create the chain and the jump-into-chain rule as first rule for provided
# table and chain
#
# usage:
# $(create_or_flush_initial_jump_chain "nat" "PREROUTING" "V_FIRST_NAT_PREROUTING")
local table_name=$1
local chain_to_search_into=$2
local chain_to_search=$3
local FOUND_RULE_NUMBER=$(find_jumpchain_rule_number $table_name $chain_to_search_into $chain_to_search)
[ "$FOUND_RULE_NUMBER" -lt "1" ] && {
echo 'create_or_flush_initial_jump_chain > '$chain_to_search' must be created..' >&2
/sbin/iptables -t $table_name -N $chain_to_search
echo 'create_or_flush_initial_jump_chain > creation of jump to chain rule for : '$chain_to_search' ' >&2
/sbin/iptables -t $table_name -I $chain_to_search_into 1 -j $chain_to_search
} || {
echo 'create_or_flush_initial_jump_chain > '$chain_to_search' must be flushed..' >&2
/sbin/iptables -t $table_name -F $chain_to_search
}

}



insert_custom_chain() {
# @ return true (bash return code 0 )  if chain is enabled , false if not
# usage:
# if insert_custom_chain 1 nat PREROUTING; then
#     append table rules here ...
# fi



    declare -Ax creator

    ## header
    creator[enabled]=$1 # 0 = false , 1 = true
    creator[table]=$2
    creator[chain]=$3
    # header footer > create custom rule name using header variables
    creator[custom_chain_name]='v_first_'"${creator[table]}"'_'"${creator[chain]}"
    ## flush
    echo '>>> deletin references for chain : '$creator[custom_chain_name] >&2

    deleted_items=$(delete_chain_references_in_default_chains "${creator[custom_chain_name]}" "${creator[table]}")
    echo '>>> deleting chain : '"${creator[custom_chain_name]}" >&2
    /sbin/iptables -t "${creator[table]}" -X "${creator[custom_chain_name]}"

    # rebuild
    [ "${creator[enabled]}" -eq "1" ] && {
    echo '>>> rebuilding chain : '$creator[custom_chain_name] >&2
    /sbin/iptables -t "${creator[table]}" -N "${creator[custom_chain_name]}"

    echo '>>> creating jump rule  : '$creator[custom_chain_name] >&2
    /sbin/iptables -t "${creator[table]}" -I "${creator[chain]}" 1 -j "${creator[custom_chain_name]}"
    return 0; # return true
    } || {
    return 1; # return false
    }
}