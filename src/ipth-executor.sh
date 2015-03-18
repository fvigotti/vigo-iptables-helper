#!/bin/bash

# BASICS -----------------------------------------------------------------------
# shell options: extended globbing
shopt -qs extglob

declare -Ax config

config[template_file]=$1

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