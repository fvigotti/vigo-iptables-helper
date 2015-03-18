#!/bin/bash


IPTH_TEMPLATE_VERSION = "1.0"

ipth_template() {



local enabled=$(ipth_forced_unload_or_value "1")
local table=nat
local chain=PREROUTING
local created_chain=$(insert_custom_chain $enabled $table $chain)

[ ! -z "$created_chain" ] && {
    /sbin/iptables  -t $table -I "$created_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix "Denied TCP: " --log-level 7
}


local enabled=$(ipth_forced_unload_or_value "1")
local table=nat
local chain=PREROUTING
local created_chain=$(autocreate_autopositioned_chain $enabled $tablename $chain_parent $chainparent_position)

[ ! -z "$created_chain" ] && {
    /sbin/iptables  -t $table -I "$created_chain" -p tcp -m limit --limit 5/min -j LOG --log-prefix "Denied TCP: " --log-level 7
}


} # END - ipth_template