#!/bin/bash

LIBVIRT_DEFAULT_URI="qemu:///system"

#####################################################
# Functions
#####################################################

function getIP {
  sleep 0.5
  resource=$1 ; ipaddr=""
  macaddr=`virsh dumpxml ${resource} \
      | grep 'mac address' \
      | awk -F"'" '{print $2}'`
  if [[ -n ${macaddr} ]]; then
    ipaddr=`virsh net-dhcp-leases default \
        | grep ${macaddr} \
        | awk -F' ' '{print $5}' \
        | awk -F'/' '{print $1}'`
  fi
  echo ${ipaddr}
}

#####################################################
# Sanity check
#####################################################

which terraform \
      terraform-provider-libvirt \
      ansible \
      nc > /dev/null

[[ $? != 0 ]] && exit $?

if [[ -d ./.cache ]]; then
  rm -rf ./.cache
  [[ $? != 0 ]] && exit $?
fi
mkdir -p ./.cache

#####################################################
# Run Terraform
#####################################################

for resource in `ls -d */`; do
  [[ -z `ls -1 ${resource} | grep '.tf$'` ]] && continue
  cd ${resource} || exit 1
  if  [[ $1 == "destroy" ]]; then
    terraform destroy -auto-approve
    cd ..
    continue
  fi
  terraform init
  terraform apply -auto-approve
  cd ..
done

[[ $1 == "destroy" ]] && exit

#####################################################
# Retrieve IP Addresses
#####################################################

echo 
echo -e "\e[96m[IP Addresses]\e[39m"

echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" >  ./.cache/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> ./.cache/hosts

for resource in `ls -d */`; do

  [[ -z `ls -1 ${resource} | grep '.tf$'` ]] && continue

  domain=`echo ${resource} | awk -F'-' '{print $1}'`
  group=` echo ${resource} | awk -F'-' '{print $2}' | sed 's|/||g'`
  amount=`cat ${resource}/*.tf \
      | sed 's/ //g' \
      | grep '^count=' \
      | sort -u \
      | awk -F'=' '{print $2}'`

  echo >> ./.cache/inventory
  echo "[${group}]" >> ./.cache/inventory

  counter=1
  while [[ ${counter} -le ${amount} ]]; do
    resource=${domain}-${group}${counter}
    while [[ -z `getIP ${resource}` ]]; do
      sleep 0.5
    done
    echo -e "${resource}: \e[32m`getIP ${resource}`\e[39m"
    echo "`getIP ${resource}` ${resource}" >> ./.cache/hosts
    echo "${resource} ansible_host=`getIP ${resource}`" >> ./.cache/inventory
    let counter=${counter}+1
  done
done

#####################################################
# Check SSH Daemon running
#####################################################

echo
echo -e "\e[96m[SSH Daemon]\e[39m"

while read line; do
  [[ -n `echo ${line} | grep localhost` ]] && continue
  ipaddr=`echo ${line} | cut -d' ' -f1`
  host=`  echo ${line} | cut -d' ' -f2`
  printf "${host} ${ipaddr} sshd_running: "
  while true; do
    nc -w1 -z ${ipaddr} 22
    [[ $? == 0 ]] && break
    sleep 0.5
  done
  echo -e "\e[32myes\e[39m"
done < ./.cache/hosts

#####################################################
# Provision with Ansible playbook
#####################################################

echo
echo -e "\e[96m[Ansible Playbook]\e[39m"
ansible-playbook -i ./.cache/inventory playbook.yml

exit $?


