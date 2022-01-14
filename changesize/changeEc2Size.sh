#!/bin/bash
# changeEc2Size.sh
# This script can take a known instance (by ID) and will change it to a different size. It'll verify 
# that size is available and will confirm each step. 
#
# potentially it wouldn't be hard to run it silently without prompts, just have to think through that.


#size variable. if left blank script will prompt for answer.
FORCE=false
startup=yes
SnapShot=false
TEST=FALSE

# temp file for facts
#TEMP=temp.ec2describe

# help functions
helptext="\
Usage $0
	--help|-h	Print this help menu
	--test|-H	Run script without making changes or stopping instances
	--instance|-i	Specify Instance ID. If not supplied script will prompt for ID
	--type|-t	Specify target size for instance
	--force|-y	Accept all prompts as yes
	--feed|-f	Present csv file of multiple Instance IDs and target sizes
	--profile|-p	Provide the profile if logged in to multiple accounts simultaneously
	--snapshot|-s	Take snapshots of all attached volumes before resizing
"
helptext2="\
Usage $0
	[ --help|-h ] [ --test|-H ] [ --instance|-i ] [ --type|-t ] [ --force|-y ] [ --feed|-f ] [ --profile|-p ] [ --snapshot|-s ]"
usage () {
echo "$helptext"
exit
}
errusage () {
echo "$helptext2"
exit
}

#function to start instance after chgsizefun
startinsfun () {
if [[ "$startup" == "yes" ]]; then
	#start instance
	echo "Starting instance ${InsID} now"
	${awscommand} ec2 start-instances --instance-ids ${InsID} --output text
## add expect to look for
#An error occurred (Unsupported) when calling the StartInstances operation: The requested configuration is currently not supported. Please check the documentation for supported configurations.
# and trigger changeback function
	
	#check if started
	echo "Waiting for instance to start"
	${awscommand} ec2 wait instance-running --instance-ids ${InsID}
else
	echo -e "You chose not to start the instance. If this was by mistake, run:\naws ec2 start-instances --instance-ids ${InsID} --output text"
fi
}
				
#function to change size
chgsizefun () {

# gathering current facts
currentSize=$(${awscommand} ec2 describe-instances --instance-ids ${InsID} --query 'Reservations[].Instances[].InstanceType' --output text)

if [ -z "$targetSize" ]; then
echo "What size would you like the instance to be?"
read targetSize

while false; do
	if $(${awscommand} ec2 describe-instance-types --instance-types --query InstanceTypes[].InstanceType --output table | grep -F ${targetSize}); then 
		echo "You chose $targetSize"
	else   
		echo "Not a recognized instanceType, please try again:"
		read targetSize
	fi
	done
fi

#stop instance
echo "Stopping instance ${InsID}"
${awscommand} ec2 stop-instances --instance-ids ${InsID} --output text

#check if stopped
echo "Waiting for instance to stop"
${awscommand} ec2 wait instance-stopped --instance-ids ${InsID}

if [[ $FORCE == "false" ]]; then
	#check current size
	echo "Current Size is $currentSize, confirm you want to modify instance to $targetSize? (y/n?)"
	read size

	while true; do
	case "$size" in
		[Yy]* )
			#check if ena is enabled
			if [[ $(${awscommand} ec2 describe-instances --instance-id ${InsID} --query "Reservations[].Instances[].EnaSupport" --output text) == "True" ]]; then
				${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --instance-type "{\"Value\": \"${targetSize}\"}" --output text
			else
				${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --ena-support --output text
				sleep 2
				${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --instance-type "{\"Value\": \"${targetSize}\"}" --output text
			fi
			startinsfun
				
			;;
				
		[Nn]* )
			echo "Keeping instance $InsID at $currentSize"
			exit
			;;
			
		* )
			echo "I didn't understand that 1"
			;;
	esac
	done
else
	#check if ena is enabled
	echo "Checking if ENA is enabled..."
	if [[ $(${awscommand} ec2 describe-instances --instance-id ${InsID} --query "Reservations[].Instances[].EnaSupport" --output text) == "True" ]]; then
		${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --instance-type "{\"Value\": \"${targetSize}\"}" --output text
	else
		echo "Modifying ENA support..."
		${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --ena-support --output text
		sleep 2
		${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --instance-type "{\"Value\": \"${targetSize}\"}" --output text
	fi
				
	startinsfun
fi
} # end of chgsizefun function


##  Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--test") set -- "$@" "-H" ;;
    "--instance") set -- "$@" "-i" ;;
    "--force") set -- "$@" "-y" ;;
    "--snapshot") set -- "$@" "-s" ;;
    "--feed") set -- "$@" "-f" ;;
    "--profile") set -- "$@" "-p" ;;
    "--type") set -- "$@" "-t" ;;
    *)        set -- "$@" "$arg"
  esac
done

##  Parse short options
OPTIND=1
while getopts "hHi:ysf:p:t:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    H)  TEST=true
        ;;
    i)  InsID=$OPTARG
        ;;
    y)  FORCE=true
        ;;
    s)  SnapShot=true
        ;;
    f)  FileFeed=$OPTARG
	FORCE=true
        ;;
    t)  targetSize=$OPTARG
        ;;
    p)  runprofile=$OPTARG
        ;;
    ?)  errusage >&2
        ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

if [ -n "$runprofile" ]; then
	awscommand="aws --profile"
else
	awscommand="aws"
fi

echo -e "\nThis script is going to resize an instance.\nThis will cause the instance to be stopped, modify the size, and then restart.\nIt will check if ENA is enabled and enable if not.\n"

if [ -n "$FileFeed" ]; then
	echo "Running script against file $FileFeed"
	while IFS=',' read InsID targetSize; do
	echo "Running resize against $InsID"
	chgsizefun
	read -n1 -p "waiting for next"
	done < <(egrep -v "^$|^#" $FileFeed)
	exit
fi

if [ -z "$InsID" ]; then
	echo "What is the instance-id for the instance you want to resize?"
	read InsID
	if $(${awscommand} ec2 describe-instances --instance ${InsID} > /dev/null ); then
		sleep .1
	else  
		if ! $(${awscommand} ec2 describe-instances --instance ${InsID} > /dev/null ); then
			echo "That was not a good instance-id for this account, try again:"
			read InsID
			if $(${awscommand} ec2 describe-instances --instance ${InsID} > /dev/null ); then
				sleep .1
			else
				echo "I couldn't find that Instance-ID, please try again with a better ID."
				exit
			fi
		fi
	fi
fi

# gathering current facts
currentSize=$(${awscommand} ec2 describe-instances --instance-ids ${InsID} --query 'Reservations[].Instances[].InstanceType' --output text)

if [[ "$TEST" == "FALSE" ]]; then
	if [[ "$SnapShot" == "true" ]]; then
	volarray=($(${awscommand} ec2 describe-instances --instance-ids ${InsID} --query 'Reservations[*].Instances[].BlockDeviceMappings[].Ebs[].VolumeId' --filter Name=block-device-mapping.status,Values=attached --output text))
	for i in ${!volarray[*]};do
		echo "Taking snapshot of ${volarray[$i]}"
		${awscommand} ec2 create-snapshot --volume-id vol-1234567890abcdef0 --description "Backup of volume prior to resize operation on $(date)"
	done
	echo "Finished taking snapshots, continuing with resize operations"
	fi
	
	if [[ "$FORCE" == "false" ]]; then
		read -p "Do you want to proceed? (y/n)? " yn
		while true; do
		case "$yn" in
			[Yy]* )
				chgsizefun
			;;
			
			[Nn]* )
				echo "You have chosen not to proceed"
				exit
			;;
			
			* )
			echo "I didn't understand that 2"
			;;
		esac
		done
	else
		chgsizefun
	fi
	exit
else
	echo -e "Running in Test mode, no changes will occur.\n\nThe variables are set:"
	echo -e "\tInstance chosen is $InsID"
	echo -e "\tSkipping prompting is set to $FORCE"
	echo -e "\tStarup option set to $startup"
	echo -e "\tCurrent size is $currentSize"
	if [ -n "$targetSize" ]; then
		echo -e "\tTarget size to change to is $targetSize"
	else
		echo -e "\tTarget size is not set"
	fi
	if [[ "$SnapShot" == "true" ]]; then
		echo -e "\tSnapshot set to true:"
		volarray=($(${awscommand} ec2 describe-instances --instance-ids ${InsID} --query 'Reservations[*].Instances[].BlockDeviceMappings[].Ebs[].VolumeId' --filter Name=block-device-mapping.status,Values=attached --output text))
		for i in ${!volarray[*]};do
			echo -e "\t\tWould have taken a snapshot of ${volarray[$i]}"
		done
	else
		echo -e "\tSnapshot option set to $SnapShot"
	fi
	echo ""
	exit
fi
