#!/bin/bash

# BASICS -----------------------------------------------------------------------
# shell options: extended globbing
shopt -qs extglob

declare -Ax config script

script[name]="${0##*/}"


print_usage() {
 echo 'usage:'${script[name]}' $templatefile $ipthfile'
}

config[template_file]=$1
config[ipth_file]=$2
IPTH_ACTION=${2:-enable}

export UNLOAD_FIREWALL_VALUE=""



[ ! -f "{$config[template_file]}" ] && {
    echo 'invalid template file path > '"{$config[template_file]}"
    print_usage
    exit 1
}

[ ! -f "{$config[ipth_file]}" ] && {
    echo 'invalid template file path > '"{$config[ipth_file]}"
    print_usage
    exit 1
}


config[output_dir]="/etc/ipth"



[ -d "${config[output_dir]}" ] || mkdir -p "${config[output_dir]}"



save_pre_test_config(){
  sudo sh -c "iptables-save > ${config[output_dir]}/saved_pre_test.rules"
  local tmp_save_filename='ipth_'$(date +%s)'_pre_test.rules'
  sudo sh -c "iptables-save > /tmp/${tmp_save_filename}"
}

run_test(){
    save_pre_test_config
}


echo '... checking version'
IPTH_TEMPLATE_VERSION "1.0"


if [ IPTH_ACTION == "disable" ]; then
    echo '... [ACTION] > DISABLE , template will be executed with default-disabled-param'
    export UNLOAD_FIREWALL_VALUE="0"
fi



echo '... set default accept policy'
set_default_accept_policy

echo '... applying template'
ipth_template

save_pre_test_config