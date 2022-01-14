#!/bin/bash
#
# This script will start or stop a known instance-id
#
# potentially it wouldn't be hard to run it silently without prompts, just have to think through that.


#instance ID variable. Script will prompt if left blank
ID=i-02fd9587d3fc2ad26

#functions
if [ -x "$( command -v timeout)" ]; then
return
else
function timeout() { perl -e 'alarm shift; exec @ARGV' "$@"; }
fi

function isitup () {
while [ $x -le 30 ]; do

if $( timeout 3 bash -c "</dev/tcp/$1/22" 2> /dev/null ); then
	echo "$ID is up and accepting connections on port 22"
	exit
fi
sleep 1
x=$(( $x + 1 ))

done
}

#stop instance function
function funstop () {
aws ec2 stop-instances --instance-ids ${ID} --output text
#check if stopped
while [ "$(aws ec2 describe-instance-status --instance-id ${ID} --query 'InstanceStatuses[].InstanceState[].Name' --output text)" == "running" ]; do echo "Waiting for ${ID} to stop"; done
echo "${ID} is stopped"
}

#start instance function
function funstart () {
aws ec2 start-instances --instance-ids ${ID} --output text
#check if started
while [ "$(aws ec2 describe-instance-status --instance-id ${ID} --query 'InstanceStatuses[].InstanceState[].Name' --output text)" != "running" ]; do echo "Waiting for ${ID} to start"; done
echo "${ID} is started"
}

if [ -z $ID ]; then
    read -p "What is the instance-id for the instance you want to resize? " ID
    if $(aws ec2 describe-instances --instance ${ID} > /dev/null ); then
        sleep .1
    else  
    	if $(aws ec2 describe-instances --instance ${ID} > /dev/null ); then
    		read -p "That was not a good instance-id for this account, try again: " ID
	    	if $(aws ec2 describe-instances --instance ${ID} > /dev/null ); then
       		 	sleep .1
		else
		        echo "I couldn't find that Instance-ID, please try again with a better ID."
		fi
	    fi
	fi
fi

echo -e "\nThis script is going to resize an instance.\nThis will cause the instance to be stopped, modify the size, and then restart.\nIt will check if ENA is enabled and enable if not.\n"

read -p "Do you want to start, or stop, an instance? start/stop " yn
case "$yn" in
start* )
funstart
isitup
echo "The system seems to be up but isn't accessible over port 22"
exit
;;

stop* )
funstop
;;

* )
echo "I didn't understand that"
;;
esac
