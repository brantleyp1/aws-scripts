#!/bin/bash
# terminateInstance.sh
#
###############################
## 
## For those times you want to make an instance go away
## 
###############################
## 

##setting some variables
FORCE=false
BACKUP=false
NOBACKUP=false

# help functions
helptext="\
Usage $0
	--help|-h		Print this help menu
	--instance-id|-i	Instance ID of the ami to be deleted
	--profile|-p		Provide the profile if logged in to multiple accounts simultaneously
	--backup|-b		Take backup AMI of instance before terminating
	--force|-f		Answer yes, useful for scripted terminations. Will create AMI automatically unless --no-backup is passed
	--no-backup|-n		Won't take backup AMI of instance before terminating, only needed if --force is used and no AMI is desired
"
helptext2="\
Usage $0
	[ --help|-h ] [ --instance-id|-i ] [ --profile|-p ] [ --backup|-b ] [ --no-backup|-n ] [ --force|-f]"
usage () {
echo "$helptext"
exit
}
errusage () {
echo "$helptext2"
exit
}

terminatefun () {
echo "Searching for Instance ${InsID} now...
"
${awscommand} ec2 describe-instances --instance-id ${InsID} --query 'Reservations[].Instances[*].{_1__Name:Tags[?Key==`Name`] | [0].Value, _2__IP:PrivateIpAddress,_3__AZ:Placement.AvailabilityZone,_4__Status:State.Name,_5__InstanceID:InstanceId,_6__Type:InstanceType,_7__Platform:Platform,_8__Key:KeyName,_9__Launched:LaunchTime}' --output table | sed 's/_[0-9]__/    /g'
wait
if [[ "$FORCE" == "TRUE" ]]; then
	yn=y
else
	echo "Are you sure you want to terminate this Instance and remove all EBS Volumes:"
	echo "Yes/No? "
	read yn
fi
while true; do
case "$yn" in
	[Yy]* ) 
		if [[ "$BACKUP" == "TRUE" ]]; then
			createAMIfun
		elif [[ "$FORCE" == "TRUE" ]] && [[ "$NOBACKUP" == "TRUE" ]]; then
			echo "Skipping AMI creation. You have 5 seconds to change your mind"
			sleep 5
		elif [[ "$FORCE" == "TRUE" ]] && [[ "$NOBACKUP" == "false" ]]; then
			createAMIfun
		else
			echo "Do you want to take an AMI backup of Instance ${InsID} first before termination?"
			echo "Yes/No? "
			read bu
			case "$bu" in
				[Yy]* ) 
					createAMIfun
					;;
						
				[Nn]* ) echo "Skipping AMI backup"
					;;
					
				* )
					echo "I didn't understand that option and cannot continue"
					exit 252
					;;
			esac
		fi
	
		echo -e "\nSetting volume(s) to delete on termination..."
		devNameArray=($(${awscommand} ec2 describe-instances --instance-id ${InsID} --query 'Reservations[*].Instances[].BlockDeviceMappings[].DeviceName' --output text))
		for i in ${devNameArray}; do
			${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --block-device-mappings "[{\"DeviceName\": \"${i}\",\"Ebs\":{\"DeleteOnTermination\":true}}]"
		done
		echo -e "\nRemoving termination protections...\n"
		${awscommand} ec2 modify-instance-attribute --instance-id ${InsID} --no-disable-api-termination
		${awscommand} ec2 terminate-instances --instance-ids ${InsID}
		echo -e "\nRemoving Instance ${InsID} has started"
		exit
		;;
			
	[Nn]* ) echo "Not removing ${InsID}, rerun if you change your mind."
		exit
		;;
		
	* )
		echo "I didn't understand that option"
		;;
esac
done
exit 0
} # end of terminatefun 



#fuction to create ami based on existing instance
createAMIfun () {
HostName=$(${awscommand} ec2 describe-tags --filters Name=resource-id,Values="${InsID}" Name=key,Values=Name --output text | awk '{ print $5 }')
if [ -z "$HostName" ]; then
	HostName=${InsID}
fi
NewImageId=$(${awscommand} ec2 create-image --instance-id "${InsID}" --reboot --name "backup-ami-${HostName}" --description "creating backup ami for ${InsID} before terminating" --output text)
echo "Beginning taking image of ${InsID} - new Image ID is ${NewImageId}
This may take several minutes."
${awscommand} ec2 wait image-available --image-id "${NewImageId}"
if [[ $(${awscommand} ec2 describe-images --image-id "${NewImageId}" --query 'Images[].StateReason[].Code' --output text) =~ "Error" ]]; then
        echo -e "\nSomething failed creating the Image. If this happens again you may need to check your access."
        exit 253
fi
if [[ ! $(${awscommand} ec2 describe-images --image-id "${NewImageId}" --query 'Images[].State' --output text) == "available" ]]; then
        echo "Image not available yet, will sleep for a few minutes then try again. Be patient..."
        sleep 180
        ${awscommand} ec2 wait image-available --image-id "${NewImageId}"
        if [[ ! $(aws --profile "${srcprofile}" ec2 describe-images --image-id "${NewImageId}" --query 'Images[].State' --output text) == "available" ]]; then
                echo -e "\nThe new image is taking a long time to complete. The script will end now and you'll need to manually check the new image then try the script again."
                exit 127
        fi
fi
} # end of createAMIfun



##  Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--profile") set -- "$@" "-p" ;;
    "--instance-id") set -- "$@" "-i" ;;
    "--force") set -- "$@" "-f" ;;
    "--backup") set -- "$@" "-b" ;;
    "--no-backup") set -- "$@" "-n" ;;
    *)        set -- "$@" "$arg"
  esac
done

##  Parse short options
OPTIND=1
while getopts "hfp:i:bn" opt
do
  case "${opt}" in
    h)  usage
        ;;
    i)  InsID=$OPTARG
        ;;
    p)  runprofile=$OPTARG
        ;;
    f)  FORCE=TRUE
        ;;
    n)  NOBACKUP=TRUE
        ;;
    s)  BACKUP=TRUE
        ;;
    ?)  errusage >&2
        ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

if [ -n "$runprofile" ]; then
	awscommand="aws --profile ${runprofile}"
else
	awscommand="aws"
fi

if [ -z "${InsID}" ]; then
	InsID="$1"
fi

if [ -z "${InsID}" ]; then
	echo "You must specify which Instance ID you want to terminate"
	errusage
fi

terminatefun 
