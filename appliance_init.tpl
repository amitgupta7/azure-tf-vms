#!/usr/bin/sh
#main function
main() {
  snap install jq
  echo "## Attempting to install the securiti appliance ##"
  sysctl -w vm.max_map_count=262144 >/dev/null
  echo 'vm.max_map_count=262144' >> etc/sysctl.conf
  mkdir -p /home/azuser/pod-installer 
  for s in $(curl -s -X 'GET' 'https://app.securiti.ai/core/v1/admin/appliance/download_url' -H 'accept: application/json' -H 'X-API-Secret:  '${x-secret} -H 'X-API-Key:  '${x-key} -H 'X-TIDENT:  '${x-tenant} | jq -r 'to_entries|map("\(.key|ascii_upcase)=\(.value|tostring)")|.[]');
  do
      export $s
  done

  for s in $(curl -s -X 'POST' \
  'https://app.securiti.ai/core/v1/admin/appliance' -H 'accept: application/json' -H 'X-API-Secret:  '${x-secret} -H 'X-API-Key:  '${x-key} -H 'X-TIDENT:  '${x-tenant}\
  -H 'Content-Type: application/json' \
  -d '{
  "owner": "'${pod_owner}'",
  "co_owners": [],
  "name": "localtest-'$(echo $RANDOM %10000+1 |bc)'",
  "desc": "",
  "send_notification": false
  }' | jq -r '{appliance_name: .data.name, appliance_id: .data.id, license: .data.license}|to_entries|map("\(.key|ascii_upcase)=\(.value|tostring)")|.[]');
  do
      export $s
  done
  curl "$DOWNLOAD_URL" --output /home/azuser/pod-installer/privaci-appliance-latest.tar
  echo "$LICENSE" > /home/azuser/pod-installer/license.txt
  touch /home/azuser/pod-installer/privaci-appliance-create.lock
  echo "##creating securiti appliance ##"
  echo $APPLIANCE_NAME >> /home/azuser/pod-installer/privaci-appliance.lock
  echo $APPLIANCE_ID >> /home/azuser/pod-installer/privaci-appliance.lock
  cd /home/azuser/pod-installer
  tar -xvf privaci-appliance-latest.tar
  STATE_DIR="/var/lib/gravity"
  IP="${privatePodIp}"
  SECRET="sai123"
  if [ "${nodeType}" = "master" ]
  then
    echo "## Attempting to install master ##"
    sudo ./gravity install --advertise-addr=$IP --token=$SECRET --cloud-provider=generic --state-dir $STATE_DIR
    kubectl wait --for=condition=Ready --timeout=120s pod/priv-appliance-redis-master-0
    kubectl exec -it $(kubectl get pods -l app=config-controller -ojsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}') securitictl register -- -l "$LICENSE"
  else
    echo "## sleeping for 30mins for master to come up ##"
    sleep 1800
    echo "## Attempting to install worker ##"
    sudo ./gravity join ${masterIp} --advertise-addr=$IP --token=$SECRET --cloud-provider=generic --role worker --state-dir $STATE_DIR
  fi
}
main