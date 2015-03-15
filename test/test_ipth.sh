#!/usr/bin/env bash

set -x
set -e
set -o pipefail

. ./../src/ipth.sh

REQUIRED_VERSION="1.0"
[ "${script[version]}" == "$REQUIRED_VERSION" ] || {
echo 'invalid version.. current = '"${script[version]}"' , required = '$REQUIRED_VERSION
exit 1 ;
}

#DOCKER_RULE_NUMBER=$(find_jumpchain_rule_number filter FORWARD DOCKER)
#echo 'filter FORWARD DOCKER > DOCKER_RULE_NUMBER='$DOCKER_RULE_NUMBER
#[ "$DOCKER_RULE_NUMBER" -gt "0" ] && echo 'docker exists!'
#
#
#chain_name="FORWARD"
#LAST_RULE_NUMBER=$(get_last_rule_number filter $chain_name)
#echo 'filter '$chain_name'  > LAST_RULE_NUMBER='$LAST_RULE_NUMBER
#[ "$LAST_RULE_NUMBER" -lt "1" ] && echo 'chain '$chain_name' is empty !'
#
#
#
#chain_name="INPUT"
#LAST_RULE_NUMBER=$(get_last_rule_number filter $chain_name )
#echo 'filter '$chain_name' > LAST_RULE_NUMBER='$LAST_RULE_NUMBER
#[ "$LAST_RULE_NUMBER" -lt "1" ] && echo 'chain '$chain_name' is empty !'
#
#
#$(create_or_flush_initial_jump_chain "nat" "PREROUTING" "V_FIRST_NAT_PREROUTING")
#/sbin/iptables  -t nat  -A V_FIRST_NAT_PREROUTING -i 136.243.20.75  -m state --state NEW -p tcp --destination-port  8126 -j ACCEPT


# PREROUTING
if find_chain_exists nat PREROUTING ; then
 echo PREROUTING exists
fi
if ! find_chain_exists nat xxx ; then
 echo xxx do not exists
fi




if insert_custom_chain 1 nat PREROUTING; then
    echo created
fi



exit 0
#$(create_or_flush_initial_jump_chain "nat" "PREROUTING" "V_FIRST_NAT_PREROUTING")
#/sbin/iptables  -t nat  -A V_FIRST_NAT_PREROUTING -i 136.243.20.75  -m state --state NEW -p tcp --destination-port  8126 -j ACCEPT


exit 0