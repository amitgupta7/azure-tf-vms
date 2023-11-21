#!/usr/bin/env bash
SECURITI_NODE_JOIN_TOKEN=securiti
INSTALL_VARS="SECURITI_INSTALL_DIR=/var/lib SECURITI_SKIP_DISK_CHECKS=true SECURITI_SKIP_DOWNLOAD_CHECKSUM=true SECURITI_NODE_JOIN_TOKEN=$SECURITI_NODE_JOIN_TOKEN"
install_home=/home/$SUDO_USER/pod-installer
lockfile=/home/$SUDO_USER/install-status.lock
touch $lockfile
err_report() {
    echo -n "Error at time: " && date
    echo; echo -n "$2 failed on line $1: "
    sed -n "$1p" $0
    echo 1 > $lockfile
    exit
}
trap 'err_report $LINENO $0' ERR

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
  echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
  mkdir -p $install_home 
  cd $install_home
  if [ "${nodeType}" = "master" ]
  then
   echo "## Attempting to install master ##"
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
  
   APPLIANCE_ID=$(cat $install_home/sai_appliance.txt| jq -r '.data.id')
   
   curl -s -X 'GET' \
      'https://app.securiti.ai/core/v1/admin/appliance/'$APPLIANCE_ID'/get_curl_master' \
      -H 'accept: application/json' \
      -H 'X-API-Secret:  '${xsecret} \
      -H 'X-API-Key:  '${xkey} \
      -H 'X-TIDENT:  '${xtenant} \
      -H 'Content-Type: application/json' \
       > $install_home/sai_curl.txt
   eval $(echo "$(cat sai_curl.txt | jq -r '.data| split("|")[0]')| $INSTALL_VARS sh -")

  else
    echo "## Attempting to install worker ##"
    curl -s -X 'GET' 'https://app.securiti.ai/core/v1/admin/appliance/download_url' \
    -H 'accept: application/json' \
    -H 'X-API-Secret:  '${xsecret} \
    -H 'X-API-Key:  '${xkey} \
    -H 'X-TIDENT:  '${xtenant} \
    > $install_home/sai_download.txt
    PACKAGE_DIR=securiti-appliance-installer
    PACKAGE_NAME=$PACKAGE_DIR.tar.gz
    DOWNLOAD_URL=$(cat $install_home/sai_download.txt| jq -r '.download_url')
    curl "$DOWNLOAD_URL" --output $install_home/$PACKAGE_NAME
    tar -xvf $PACKAGE_NAME
    cd $install_home/$PACKAGE_DIR
    INSTALL_VARS="$INSTALL_VARS SECURITI_NODE_KIND=agent SECURITI_LEADER_URL=https://$masterIp:6443 SECURITI_DOWNLOAD_URL=$DOWNLOAD_URL"
    echo $INSTALL_VARS
    echo "## Sleep 60s for control plane installation ##"
    sleep 60
    export $INSTALL_VARS && sh install.sh 
  fi
echo 0 > $lockfile
