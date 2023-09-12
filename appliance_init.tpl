#!/usr/bin/sh
set -o xtrace
install_home=/home/$SUDO_USER/pod-installer
lockfile=$install_home/install-status.lock

while getopts r:k:s:t:o:n:i: flag
do
    case "${flag}" in
        n) nodeType=${OPTARG};;
        o) pod_owner=${OPTARG};;
        r) masterIp=${OPTARG};;
        k) xkey=${OPTARG};;
        s) xsecret=${OPTARG};;
        t) xtenant=${OPTARG};;
        i) privatePodIp=${OPTARG};;        
    esac
done
#main function

  snap install jq
  echo "## Attempting to install the securiti appliance ##"
  sysctl -w vm.max_map_count=262144 >/dev/null
  echo 'vm.max_map_count=262144' >> etc/sysctl.conf
  mkdir -p $install_home 
  touch $lockfile
  curl -s -X 'GET' 'https://app.securiti.ai/core/v1/admin/appliance/download_url' \
  -H 'accept: application/json' \
  -H 'X-API-Secret:  '${xsecret} \
  -H 'X-API-Key:  '${xkey} \
  -H 'X-TIDENT:  '${xtenant} \
  > $install_home/sai_download.txt

  DOWNLOAD_URL=$(cat $install_home/sai_download.txt| jq -r '.download_url')
  curl "$DOWNLOAD_URL" --output $install_home/privaci-appliance-latest.tar

  cd $install_home
  tar -xvf privaci-appliance-latest.tar
  STATE_DIR="/var/lib/gravity"
  IP="${privatePodIp}"
  SECRET="sai123"
  if [ "${nodeType}" = "master" ]
  then
    echo "## Attempting to install master ##"
    ./gravity install --advertise-addr=$IP --token=$SECRET --cloud-provider=generic --state-dir $STATE_DIR
    kubectl wait --for=condition=Ready --timeout=120s pod/priv-appliance-redis-master-0
    curl -s -X 'POST' \
      'https://app.securiti.ai/core/v1/admin/appliance' \
      -H 'accept: application/json' \
      -H 'X-API-Secret:  '${xsecret} \
      -H 'X-API-Key:  '${xkey} \
      -H 'X-TIDENT:  '${xtenant} \
      -H 'Content-Type: application/json' \
      -d '{
      "owner": "'${pod_owner}'",
      "co_owners": [],
      "name": "localtest-'$(date +"%s")'",
      "desc": "",
      "send_notification": false
      }' > $install_home/sai_appliance.txt
  
    SAI_LICENSE=$(cat $install_home/sai_appliance.txt| jq -r '.data.license')
    echo "$SAI_LICENSE" > $install_home/license.txt
    kubectl exec -it $(kubectl get pods -l app=config-controller -ojsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}') securitictl register -- -l "$SAI_LICENSE"
  else
    echo "## sleeping for 30mins for master to come up ##"
    sleep 1800
    echo "## Attempting to install worker ##"
    ./gravity join ${masterIp} --advertise-addr=$IP --token=$SECRET --cloud-provider=generic --role worker --state-dir $STATE_DIR
  fi
echo $? > $lockfile
