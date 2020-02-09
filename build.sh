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
      virsh \
      nc > /dev/null

[[ $? != 0 ]] && exit $?

#####################################################
# Run Terraform
#####################################################

cd ./terraform || exit 1
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
cd ..
[[ $1 == "destroy" ]] && exit

#####################################################
# Retrieve IP Addresses
#####################################################

cd ./ansible || exit 1
rm -f inventory.ini hosts id_rsa.pub

echo
echo -e "\e[96m[IP Addresses]\e[39m"

echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" >  hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> hosts

for resource in `ls -d ../terraform/*/`; do

  [[ -z `ls -1 ../terraform/${resource} | grep '.tf$'` ]] && continue

  resource=`basename ${resource}`
  domain=`echo ${resource} | awk -F'-' '{print $1}'`
  group=` echo ${resource} | awk -F'-' '{print $2}' | sed 's|/||g'`
  amount=`cat ../terraform/${resource}/*.tf \
      | sed 's/ //g' \
      | grep '^count=' \
      | sort -u \
      | awk -F'=' '{print $2}'`

  echo >> inventory.ini
  echo "[${group}]" >> inventory.ini

  counter=1
  while [[ ${counter} -le ${amount} ]]; do
    resource=${domain}-${group}${counter}
    while [[ -z `getIP ${resource}` ]]; do
      sleep 0.5
    done
    echo -e "${resource}: \e[32m`getIP ${resource}`\e[39m"
    echo "`getIP ${resource}` ${resource}" >> hosts
    echo "${resource} ansible_host=`getIP ${resource}`" >> inventory.ini
    let counter=${counter}+1
  done
done
echo >> inventory.ini

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
done < hosts

#####################################################
# Provision with Ansible playbook
#####################################################

echo
echo -e "\e[96m[Ansible Playbook]\e[39m"
ansible-playbook -i ./inventory.ini playbook.yml

exit $?


