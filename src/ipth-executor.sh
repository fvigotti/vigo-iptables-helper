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
config[ipth_path]=$2

[ ! -f "{$config[template_file]}" ] && {
    echo 'invalid template file path > '"{$config[template_file]}"
    print_usage
    exit 1
}

[ ! -f "{$config[ipth_path]}" ] && {
    echo 'invalid template file path > '"{$config[ipth_path]}"
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




save_pre_test_config