#!/bin/bash

set -x
set -e
set -o pipefail

. ./../src/ipth.sh

ipth_check_version "1.1"

test_chain_name="test_chain"
test_table="filter"

# delete test chain if exist
if find_chain_exists $test_table $test_chain_name ; then
    echo 'test chain:'$test_chain_name' exists and will be deleted before test can start '
    recursive_delete_chain $test_table $test_chain_name
fi


# create chain and then chain should exists
create_chain $test_table $test_chain_name
if ! find_chain_exists $test_table  $test_chain_name ; then
    echo 'error, '$test_chain_name'  chain should exists at this point '
    exit 1
fi




# generate jump and count references
create_jump_rule $test_table 'INPUT' $test_chain_name 'first'
count_references=$(get_chain_references_count $test_table $test_chain_name)
[ "${count_references}" == "1" ] || {
    echo 'error, references count should be 1'
    exit 1
}
create_jump_rule $test_table 'OUTPUT' $test_chain_name 'first'

count_references=$(get_chain_references_count $test_table $test_chain_name)
[ "${count_references}" == "2" ] || {
    echo 'error, references count should be 2'
    exit 1
}

## now delete chain with references
recursive_delete_chain $test_table $test_chain_name
if find_chain_exists $test_table  $test_chain_name ; then
    echo 'error, '$test_chain_name'  chain should has been removed '
    exit 1
fi




# test chain name generator :
[ "$(autogenerate_custom_chain_name 'filter' 'INPUT' 'first')" == "v_first_filter_INPUT" ] || {
    echo 'error, wrong expectations on generated name '
    exit 1
}
[ "$(autogenerate_custom_chain_name 'filter' 'INPUT' 'last')" == "v_last_filter_INPUT" ] || {
    echo 'error, wrong expectations on generated name '
    exit 1
}


generated_table=$(autocreate_autopositioned_chain 0 'filter' 'INPUT' 'first')
[ ! -z "$generated_table" ] && {
    echo 'error, table should has been disabled! > '$generated_table
    exit 1
}

generated_table=$(autocreate_autopositioned_chain 1 'filter' 'INPUT' 'first')
[ -z "$generated_table" ] && {
    echo 'error, table should has been enabled! > '$generated_table
    exit 1
}
count_references=$(get_chain_references_count 'filter' $generated_table)
[ "${count_references}" == "1" ] || {
    echo 'error, references count should be 1'
    exit 1
}



## -- TEMPLATE SAMPLE
tablename="filter"
chainparent_position="first"
chain_parent="INPUT"
enabled="1"
# full & recreate rule
built_chain=$(autocreate_autopositioned_chain $enabled $tablename $chain_parent $chainparent_position)
# if created, apply rules
[ ! -z "$built_chain" ] && {
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix "Denied TCP: " --log-level 7
/sbin/iptables  -t  $tablename  -A "$built_chain" -p tcp -m limit --limit 51/min -j LOG --log-prefix "Denied TCP2: " --log-level 7
}

## test assertions
rules_count=$(get_last_rule_number $tablename $built_chain)
[ "${rules_count}" == "2" ] || {
    echo 'error, unexpected rules count '
    exit 1
}
recursive_delete_chain $tablename $built_chain




# test with two custom chain, as first and last
# -- todo

echo " TEST OK ! "
exit 0