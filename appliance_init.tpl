#!/usr/bin/env bash

echo "download url" $1
echo "license" $2

set -o xtrace
set -o pipefail
set -o nounset

SYSTEM_STATS_FILE="system-monitoring.log"
#setting inotify to 1048576 if not set properly
setInotifyWatch(){
  sysctl -w fs.inotify.max_user_watches=1048576 >/dev/null
  file="/etc/sysctl.d/*inotify.conf"
  inotify=`cat  $file | grep -i "fs.inotify.max_user_watches"`
  if [[ ! -f $file ]] || [[ "$inotify" == "" ]]; then
    echo 'fs.inotify.max_user_watches=1048576' >> $file
   else
    sed -i '/fs.inotify.max_user_watches/c\fs.inotify.max_user_watches=1048576' $file
   fi
}
#setting bridge-nf-call-iptables to 1 if not set properly
setBridgeNfCallIptables(){
  sysctl -w net.bridge.bridge-nf-call-iptables=1 >/dev/null
  file="/etc/sysctl.d/10-bridge-nf-call-iptables.conf"
  bridgeNf=`cat  $file | grep -i "net.bridge.bridge-nf-call-iptables"`
  if [[ ! -f $file ]] || [[ "$bridgeNf" == "" ]]; then
    echo 'net.bridge.bridge-nf-call-iptables=1' >> $file
   else
    sed -i '/net.bridge.bridge-nf-call-iptables/c\net.bridge.bridge-nf-call-iptables=1' $file
   fi
}
#setting ip4_forward to 1 if not set properly
setIpForward(){
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  file="/etc/sysctl.conf"
  ipForward=`cat  $file | grep -i "net.ipv4.ip_forward"`
  if [[ ! -f $file ]] || [[ "$ipForward" == "" ]]; then
    echo 'net.ipv4.ip_forward=1' >> $file
   else
    sed -i '/net.ipv4.ip_forward/c\net.ipv4.ip_forward=1' $file
   fi
}
#setting VmMaxMapCount to 262144 if not set properly
setVmMaxMapCount(){
  sysctl -w vm.max_map_count=262144 >/dev/null
  file="/etc/sysctl.conf"
  vmMaxMapCount=`cat  $file | grep -i "vm.max_map_count"`
  if [[ ! -f $file ]] || [[ "$vmMaxMapCount" == "" ]]; then
    echo 'vm.max_map_count=262144' >> $file
   else
    sed -i '/vm.max_map_count/c\vm.max_map_count=262144' $file
   fi
}
#verifying and loading all kernel modules required by gravitational
verifyandLoadKernelModules(){
  modules=(br_netfilter overlay ebtable ebtable_filter ip_tables iptable_filter iptable_nat)
  for module in $${modules[*]}
  do
    module_check=`lsmod | grep $module`
    if [ -z "$module_check" ]; then
       modprobe $module
     fi
  done
  file="/etc/modules-load.d/netfilter.conf"
  br_netfilter=`cat  $file | grep -i br_netfilter`
  if [[ ! -f $file ]] || [[ "$br_netfilter" == "" ]]; then
     echo 'br_netfilter' >> $file
   fi
   file="/etc/modules-load.d/overlay.conf"
  overlay=`cat $file | grep -i overlay`
  if [[ ! -f $file ]] || [[ "$overlay" == "" ]]; then
     echo 'overlay' >> $file
   fi
   file="/etc/modules-load.d/network.conf"
  ebtable_filter=`cat $file | grep -i ebtable_filter`
  if [[ ! -f $file ]] || [[ "$ebtable_filter" == "" ]]; then
     echo 'ebtable_filter' >> $file
   fi
   file="/etc/modules-load.d/iptable.conf"
  ip_table=`cat $file | grep -i ip_table`
  if [[ ! -f $file ]] || [[ "$ip_table" == "" ]]; then
     echo 'ip_table' >> $file
  fi
  iptable_filter=`cat $file | grep -i iptable_filter`
  if [[ ! -f $file ]] || [[ "$iptable_filter" == "" ]]; then
    echo 'iptable_filter' >> $file
  fi
  iptable_nat=`cat $file | grep -i iptable_nat`
  if [[ ! -f $file ]] || [[ "$iptable_nat" == "" ]]; then
    echo 'iptable_nat' >> $file
  fi
}
#CPU and memory monitoring function
monitorCPUandMem(){
  printf "LISTING COMMANDS BASED ON HIGHEST CPU USAGE\n\n"
  ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%cpu | head -5
  printf "\n\n"
  printf "LISTING COMMANDS BASED ON HIGHEST MEMORY USAGE\n\n"
  ps -eo pid,ppid,cmd,%mem,%cpu --sort=-%mem | head -5
  printf "\n\n"
} >> $SYSTEM_STATS_FILE
#monitoring system disk IO during the install/upgrade process
#https://www.kernel.org/doc/Documentation/ABI/testing/procfs-diskstats
monitorIO(){
  printf "MONITORING DISK I/O OF SYSTEM\n\n"
  printf "*******|*********READS**********|*********WRITES***********|*********************I/O*******************|****\n"
  printf "Dev    | Success    Spent(ms)   | Success       Spent(ms)  | Progress  Spent(ms) Weighted_Spent_I/O(ms)|Used\n"
  statistics=`cat /proc/diskstats`
  disk=`lsblk | grep -i disk | cut -d" " -f1`
  SAVEIFS=$IFS
  IFS=$'\n'
  statistics=($statistics)
  disk=($disk)
  IFS=$SAVEIFS
  for (( i=0; i<$${#statistics[@]}; i++ )); do
    read -ra DISKSTAT <<< $${statistics[$i]}
    if [[ " $${disk[@]} " =~ " $${DISKSTAT[2]} " ]]; then
      used=`df -h | grep -i $${DISKSTAT[2]} | awk '{print $5}'`
      printf "%-8s %-11s%-14s%-14s%-13s%-10s%-10s%-23s%-4s" "$${DISKSTAT[2]}" "$${DISKSTAT[3]}" "$${DISKSTAT[6]}"  "$${DISKSTAT[7]}" "$${DISKSTAT[10]}" "$${DISKSTAT[11]}" "$${DISKSTAT[12]}" "$${DISKSTAT[13]}" "$${used}"
      printf "\n"
    fi
  done
  printf "\n\n"
} >> $SYSTEM_STATS_FILE
#System monitoring function running every 3 seconds in background to collect system stats
monitorSystem() {
  while true
  do
    monitorCPUandMem
    monitorIO
    sleep 3
  done
}
#main driver function
main() {
  rm -rf /mnt/installation/*
  rm -rf /mnt/installation/.gravity
  mkdir -p /mnt/installation
  cd /mnt/installation
  startProcessTime=$(date +%s)
  printf "\t\tSTARTING SYSTEM MONITORING\n\n" > $SYSTEM_STATS_FILE
  monitorSystem &
  MonitorPID=$!
  setInotifyWatch
  setBridgeNfCallIptables
  setIpForward
  setVmMaxMapCount
  verifyandLoadKernelModules
  curl "$1" --output privaci-appliance-latest.tar
  tar -xvf privaci-appliance-latest.tar
  IP=$(getent hosts `hostname` | awk '{print $1}')
  SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
  sudo ./gravity install --advertise-addr=$IP --token=$SECRET --cloud-provider=generic --state-dir /var/lib/gravity 
  echo "Waiting for Redis DB"
  kubectl wait --for=condition=Ready --timeout=120s pod/priv-appliance-redis-master-0
  kubectl exec -it $(kubectl get pods -l app=config-controller -ojsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}') securitictl register -- -l $2
  rm -rf packages
  kill -TERM $MonitorPID >/dev/null
  endProcessTime=$(date +%s)
  elapsedTime=$((endProcessTime - startProcessTime))
  printf "Total time elasped: %-8s seconds" "$${elapsedTime}" >> $SYSTEM_STATS_FILE
}
main