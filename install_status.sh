#!/usr/bin/sh
set -e
R='\033[1;31m'
G='\033[1;32m'
if [ -f $1 ] 
 then
   echo "Existing Installation Lock File Found: "$1
   echo -n 'Installer Status: ' 
   if [ ! -s $1 ]
    then
        echo "${G}In Progress"
    else
        state=$(cat $1)
        if [ $state -eq 0 ]
            then
              echo "${G}Completed on $3"
              if [ $3 = "master" ]
                then
                 SVC_NAME=k3s
                 kubectl get nodes
                 kubectl get pods -A -o=custom-columns=NODE-IP:.status.hostIP,NAME:.metadata.name,STATUS:.status.phase | sort -r
                else
                 SVC_NAME=k3s-agent
              fi
                echo "Service status of $SVC_NAME on $3: $(systemctl is-active --quiet $SVC_NAME && echo "${G}Active" || echo "${R}Not-Active")" 
                systemctl --no-pager status $SVC_NAME | head -5
                exit 0
            else
                echo "${R}Error"
                $2 && (echo "clearing lockfile: $1" && rm $1 && echo "cleared lockfile, rerunning installer as nohup (rerun tfaa to tail install log)") || (tail /home/$SUDO_USER/appliance_init.out && echo "[EXPERIMENTAL] Use command to clear lockfile and rerun the install:  tfaa -var=clr_lock=true") 
                exit 0
        fi   
    fi
    tail -f /home/$SUDO_USER/appliance_init.out
 else
   exit 0
fi
