#!/usr/bin/sh
set -e
if [ -f $1 ] 
 then
   echo "Existing Installation Lock File Found: "$1
   echo -n 'Installer Status: ' 
   if [ ! -s $1 ]
    then
        echo 'In Progress'
    else
        state=$(cat $1)
        if [ $state -eq 0 ]
            then
                echo 'Completed'
                gravity status
                sudo -u $SUDO_USER kubectl get nodes
                sudo -u $SUDO_USER kubectl get pods
                exit 0
            else
                echo 'Error' 
                $2 && (echo "clearing lockfile: $1" && rm $1 && echo "cleared lockfile, rerunning installer as nohup (rerun tfaa to tail install log)") || (tail /home/$SUDO_USER/appliance_init.out && echo "Use command to clear lockfile and rerun the install:  tfaa -var=clr_lock=true") 
                exit 0
        fi   
    fi
    tail -f /home/$SUDO_USER/appliance_init.out
 else
   exit 0
fi
