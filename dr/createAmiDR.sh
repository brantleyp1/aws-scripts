#!/bin/bash
# createAmi.sh
#
################################
## 
## this is a clone of migrateInstance.sh but adapted for DR
## 
## it doesn't require the key portions, and the tagging is heavily modified to 
## not worry about fixing tags but just copying the existing tags
## 
## should add "-DR" to tags and hostnames where applicable
## 
################################
## 

#setting some parameters

rebootIns="no-"


## functions. I love functions.

#help function
## removing test for now, need to figure out how to impliment it
helptext="\
Usage: $0
        --help | -h             - This menu
        --instance | -i         - Required - source instance to be migrated
        --file | -f		- Provide list of instances to make AMIs of, must be in same region/account
        --profile | -p          - The profile/account you want to copy instances from
        --reboot | -r           - Allow create-image to reboot instance, much faster but will cause interruption
"
errorhelptext="\
Usage: $0
        [--help|-h] [--instance|-i] [--file|-f] [--profile|-p] [--reboot|-r]
"
usage () {
echo "$helptext"
exit
}
errusage () {
echo "$errorhelptext"
exit 255
}

# date functions
if [[ "$OSTYPE" =~ "darwin" ]]; then
        # date for the script
        NowDate=$(date -j +%Y%m%d)
else
        # date for the script
        NowDate=$(date +%Y%m%d)
fi


#tags functions
buildtagfun () {
#tagarray=($(${awscommand} ec2 describe-tags --filters Name=resource-id,Values="${InsId}" --output text | awk -F $'\t' " { print \"'Key=\"\$2\",Value=\"\$5\"'\" } "))
#tagarray=($(${awscommand} ec2 describe-tags --filters Name=resource-id,Values="${InsId}" --output text | awk -F $'\t' " { if (\$5) { print \"'Key=\"\$2\",Value=\"\$5\"'\" } else { print \"'Key=\"\$2\",Value=N/A'\" }} "))
tagarray=($(${awscommand} ec2 describe-tags --filters Name=resource-id,Values="${InsId}" --output text | awk -F $'\t' " { if (\$5) { print \"'Key=\"\$2\",Value=\"\$5\"'\" } else { print \"'Key=\"\$2\",Value=N/A'\" }} "| sed 's/ /_/g'))

# set var HostName
for i in ${!tagarray[@]}; do
	if [[ "${tagarray[$i]}" =~ "Key=Name" ]]; then
		HostName=$(echo ${tagarray[$i]} | awk -F'=' '{ print $3 }' | tr -d \')
	fi
done

# fixing tags for DR use
tempvar=''
for i in ${!tagarray[@]}; do
if [[ "${tagarray[$i]}" =~ "Key=Name" ]]; then
	tempvar="$(echo ${tagarray[$i]} | sed 's/.$/-DR&/')"
	unset tagarray[$i]
	tagarray[$i]=$tempvar
fi
done

for i in ${!tagarray[@]}; do
if [[ "${tagarray[$i]}" =~ "Key=aws" ]]; then
	unset tagarray[$i]
fi
done

for i in ${!tagarray[@]}; do
if [[ "${tagarray[$i]}" =~ "Key=bbva-ops-backup-plan" ]]; then
	unset tagarray[$i]
	tagarray[$i]="Key=bbva-ops-backup-plan,Value=Never"
fi
done

for i in ${!tagarray[@]}; do
if [[ "${tagarray[$i]}" =~ "Key=bbva-ops-logicalenvironment" ]]; then
	unset tagarray[$i]
	tagarray[$i]="Key=bbva-ops-logicalenvironment,Value=DR"
fi
done

for i in ${!tagarray[@]}; do
if [[ "${tagarray[$i]}" =~ "Key=bbva-ops-operationalband" ]]; then
	unset tagarray[$i]
	tagarray[$i]="Key=bbva-ops-operationalband,Value=DR"
fi
done

#Adding instancetype tag for dr use only
InstanceType=$(${awscommand} ec2 describe-instances --instance-ids ${InsId} --query 'Reservations[].Instances[].InstanceType' --output text)
tagarray+=("Key=bbva-dr-instancetype,Value=${InstanceType}")
#removing quotes for create-tags step
tagtext=$(echo ${tagarray[@]} | tr -d \')

} # end of buildtagfun


#fuction to create ami based on existing instance
createAMIfun () {
ImageId=$(${awscommand} ec2 create-image --instance-id "${InsId}" --${rebootIns}reboot --name "DR_${HostName}_${InsId}_${NowDate}" --description "creating ami for ${InsId} for $(date +%Y%b) DR exercise" --output text)
echo "Beginning taking image of ${InsId} with the ${rebootIns}reboot flag - new Image ID is ${ImageId}
This may take several minutes."
tagAMIfun
} # end of createAMIfun


# function to use tags to create tags on ami tagAMIfun
tagAMIfun () {
${awscommand} ec2 create-tags --resources ${ImageId} --tags ${tagtext}
#${awscommand} ec2 create-tags --resources ${ImageId} --tags ${tagarray[@]}
echo "Applying tags to AMI ${ImageId}"
} # end of tagAMIfun


# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--instance") set -- "$@" "-i" ;;
    "--file") set -- "$@" "-f" ;;
    "--profile") set -- "$@" "-p" ;;
    "--reboot") set -- "$@" "-r" ;;
    *)        set -- "$@" "$arg"
  esac
done

# Parse short options
OPTIND=1
while getopts "hi:rp:f:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    i)  InsId=$OPTARG
        ;;
    r)  rebootIns=""
        ;;
    f)  FileFeed=$OPTARG
        ;;
    p)  runprofile=$OPTARG
        ;;
    ?)  errusage >&2
        ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters


#aws command structure
if [ -n "$runprofile" ]; then
        awscommand="aws --profile ${runprofile}"
else
        awscommand="aws"
fi


#grouping all in main
main () {
if [ -z "${InsId}" ]; then 
	echo "You must supply an Instance ID to copy"
	exit
fi

echo "Starting createAMI.sh script now"
echo "setting NowDate as $NowDate"

echo "Copying tags from existing Instance..."
buildtagfun
wait

createAMIfun
} # end of main function

if [ -z "$FileFeed" ]; then
	main
else
	feedarray=($(cat ${FileFeed}))
	for i in ${feedarray[@]}; do
		InsId="$i"
		main "$InsId"
	done
fi

exit
