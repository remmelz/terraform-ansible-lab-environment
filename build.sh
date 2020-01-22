#!/bin/bash
#
# Simple build script
#
################################################
# Default variables
################################################

NETWORK="192.168."
LIBVIRT_DEFAULT_URI="qemu:///system"
ARG=$1

export LIBVIRT_DEFAULT_URI

################################################
# Functions
################################################

function _showhelp() {
    echo "Usage:"
    echo 
    echo "  $0 apply | destroy" 
    echo
    echo "  -a            Apply builds or changes infrastructure"
    echo "  -d            Destroy Terraform-managed infrastructure"
    echo "  -n <iprange>  When building, detect new host in this IP range (default 192.168.)"
    echo
    exit 1
}

function _tf_init() {
  terraform init
}

function _tf_apply() {
  terraform apply -auto-approve
}

function _tf_destroy() {
  terraform destroy -auto-approve
}

function _ansible_run() {
  ansible-playbook -i "${IPADDR}," ./.cache/playbook.yml
}

function _tf_count() {
  count=`cat *.tf | sed 's/ //g' \
    | grep '^count' | sort -u | cut -d'=' -f2`
  echo ${count}
}

################################################
# Getting options
################################################

while getopts "adn:i:" OPT; do
  case ${OPT} in
    a ) ACTION="apply"     ;;
    d ) ACTION="destroy"   ;;
    n ) NETWORK=${OPTARG}  ;;
    i ) INSTANCE=${OPTARG} ;;
  esac
done

[[ $1 == "apply" ]]   && ACTION="apply"
[[ $1 == "destroy" ]] && ACTION="destroy"
[[ -z $1 ]]           && _showhelp

################################################
# Shutdown and remove the environment
################################################

if [[ ${ACTION} == "destroy" ]]; then
  _tf_destroy
  exit $?
fi

################################################
# Provision Virtual Machine
################################################

mkdir -v ./.cache

if [[ ${ACTION} != "apply" ]]; then
  _showhelp
fi

C=1
while [[ ${C} -lt 30 ]]; do

  _tf_apply

  IPCOUNT=`grep ${NETWORK} terraform.tfstate \
	  | sed 's/ //g' | sort -u | wc -l`

  if [[ ${IPCOUNT} -eq `_tf_count` ]]; then
    grep ${NETWORK} terraform.tfstate \
      | sed 's/ //g' | sed 's/"//g' \
      | sort -u > ./.cache/iplist
    break
  fi

  echo "Retrieving IP addresses, trying again in 5 sec...."
  sleep 5

  let C=${C}+1
done

if [[ ! -f ./.cache/iplist ]]; then
  echo "No IP addresses retrieved. Something went wrong..."
  _tf_destroy
  exit 1
fi

################################################
# Check if SSH Daemon is running
################################################

echo "Waiting for SSH connectivity:"
while true; do
  C=0
  for IP in `cat ./.cache/iplist`; do
    nc -w1 -z ${IP} 22
    if [[ $? == 0 ]]; then 
      printf "+"
      let C=$C+1
    else
      printf "-"
    fi
    sleep 0.5
  done
  [[ ${C} -eq ${IPCOUNT} ]] && break
done

################################################
# Generate hosts file
################################################

echo
echo "Generating hosts file."
echo "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4" >  ./.cache/hosts
echo "::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" >> ./.cache/hosts

C=1
for IPADDR in `cat ./.cache/iplist`; do
  echo "${IPADDR} ansible${C}.homelab.local" >> ./.cache/hosts
  let C=${C}+1
done

################################################
# Provision Applications
################################################

C=1
for IPADDR in `cat ./.cache/iplist`; do

  cat ./playbooks/base.tmpl \
    | sed "s/%instance%/${C}/" > ./.cache/playbook.yml

  if [[ $C -eq 1 ]]; then
    cat ./playbooks/mngt.tmpl >> ./.cache/playbook.yml
    _ansible_run
  else
    cat ./playbooks/auth.tmpl >> ./.cache/playbook.yml
    _ansible_run
  fi

  let C=${C}+1
done

# Remove cache files
rm -rf ./.cache

exit

