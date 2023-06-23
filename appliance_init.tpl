#!/usr/bin/sh set -e -x
#main driver function
main() {
  echo "## Attempting to install the securiti appliance ##"
  mkdir -p /home/azuser/pod-installer 
  curl "${downloadurl}" --output /home/azuser//pod-installer/privaci-appliance-latest.tar
  echo "${license}" > /home/azuser//pod-installer/license.txt
  cd /home/azuser/pod-installer
  tar -xvf privaci-appliance-latest.tar
  IP="${privatePodIp}"
  SECRET="sai123"
  if [ "${nodeType}" = "master" ]
  then
    echo "## Attempting to install master ##"
    sudo ./gravity install --advertise-addr=$IP --token=$SECRET --cloud-provider=generic --state-dir /var/lib/gravity}
    kubectl wait --for=condition=Ready --timeout=120s pod/priv-appliance-redis-master-0
    kubectl exec -it $(kubectl get pods -l app=config-controller -ojsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}') securitictl register -- -l "${license}"
  else
    echo "## sleeping for 30mins for master to come up ##"
    sleep 1800
    echo "## Attempting to install worker ##"
    sudo ./gravity join ${masterIp} --advertise-addr=$IP --token=$SECRET --cloud-provider=generic --role worker --state-dir /var/lib/gravity
  fi
}
main