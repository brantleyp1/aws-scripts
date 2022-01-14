#!/bin/bash
# deleteAmi.sh
#
###############################
## 
## Quickly deregister an AMI and
## delete the associated snapshots
## 
###############################
## 

##setting some variables
FORCE=false

# help functions
helptext="\
Usage $0
	--help|-h	Print this help menu
	--ami-id|-a	AMI ID of the ami to be deleted
	--profile|-p	Provide the profile if logged in to multiple accounts simultaneously
	--force|-f	Run script without interaction
"
helptext2="\
Usage $0
	[ --help|-h ] [ --ami-id|-a ] [ --profile|-p ] [ --force|-f ]"
usage () {
echo "$helptext"
exit
}
errusage () {
echo "$helptext2"
exit
}

deleteamifun () {
echo "Starting script now...
"
${awscommand} ec2 describe-images --image-id ${AMIID} --query 'Images[*].{Created:CreationDate,AmiID:ImageId,Location:ImageLocation,Description:Description}' --output table | grep -v Describe
wait
if [[ "$FORCE" == "TRUE" ]]; then
	yn=y
else
	echo "Are you sure you want to delete this AMI:"
	echo "Yes/No? "
	read yn
fi
while true; do
case "$yn" in
	[Yy]* ) snaparray=($(${awscommand} ec2 describe-images --image-ids ${AMIID} --query 'Images[].BlockDeviceMappings[].Ebs[].SnapshotId' --output text))
		echo "Deregistering ${AMIID}"
		${awscommand} ec2 deregister-image --image-id ${AMIID}
		for i in ${snaparray}; do
			echo "Deleteting snapshot $i"
			${awscommand} ec2 delete-snapshot --snapshot-id $i
		done
		echo -e "\nDeleteting $AMIID is complete"
		exit
		;;
			
	[Nn]* ) echo "Not deleting ${AMIID}, rerun if you change your mind."
		exit
		;;
		
	* )
		echo "I didn't understand that option"
		;;
esac
done
} # end of deleteamifun 

##  Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--profile") set -- "$@" "-p" ;;
    "--ami-id") set -- "$@" "-a" ;;
    "--force") set -- "$@" "-f" ;;
    *)        set -- "$@" "$arg"
  esac
done

##  Parse short options
OPTIND=1
while getopts "hfp:a:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    a)  AMIID=$OPTARG
        ;;
    p)  runprofile=$OPTARG
        ;;
    f)  FORCE=TRUE
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

if [ -z "${AMIID}" ]; then
	AMIID="$1"
fi

if [ -z "${AMIID}" ]; then
	echo "You must specify which AMI ID you want to delete"
	errusage
fi

deleteamifun 
