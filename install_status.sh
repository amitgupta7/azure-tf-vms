#!/usr/bin/sh
set -e
if [ -f $1 ] 
 then
   echo "Existing Installation Lock File Found: "$1
   echo -n 'Installer Status: ' 
   if [ ! -s $1 ]
    then
        echo 'Downloading Installer'
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
                echo 'In Progress' 
        fi   
    fi
    tail -f /home/$SUDO_USER/appliance_init.out
 else
   exit 0
fi
