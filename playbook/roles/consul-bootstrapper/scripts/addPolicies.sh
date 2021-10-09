#! /bin/bash
if [ "$#" -gt 2 ]; then
  cd .
else
  cd /etc/consul-policies/
fi

if [ "$#" -lt 2 ]; then
  echo "$0 bootstrap-token http_addr"
  exit
fi

shopt -s globstar
for file in **/*.hcl; 
do 
  policy_name=`echo "$file" | tr '/' '-' | grep -Po '^.*(?=\..*$)'`; 
  if [[ ! -z  "$policy_name" ]];
  then
    echo "Added policy for $policy_name";
    consul acl policy create -name $policy_name -rules @$file -http-addr="$2" -token "$1"

    echo $?
  fi
done