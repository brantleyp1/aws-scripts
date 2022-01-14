#!/bin/bash
# shareImage.sh
#####################################
#
# This script should allow you to share the base AMI from one account to another.
# It assumes you want to share FROM the IT Service Managment account, but that is configurable.
# It will also check to see if the target account is already in the allowed permissions list.
# 
# A step will still need to be completed to allow the key for the snapshot ID if encrypted
# that must be done in the console at this time.
#
# TODO HERE
# fix command to allow either profile first
#
#####################################

# the parameters that need to be set to run this script. Can be set here or at command line
WhatImage=
WhatTargetAcct=
WhatBand=

# Assumed to be ITSM, script will accept others though
SrcAcct=303068756901

# Leave blank
TEST=

## usage functions
usage(){
echo -e "
usage: $0
	-h|--help		Print this help file
	-H|--test		Test your settings before you commit
	-i|--image		The image you want to search for, i.e. rhel
			If unsure, run this to see a list of BBVA-EA approved images:
			\"aws ec2 describe-images --owners 303068756901 --query 'Images[?contains(ImageLocation, \`bbva\`) == \`true\`].[Name]' --output text\"
	-b|--band		Set the band, i.e. play. --band and --target must be used together
	-t|--target		Set the destination account, i.e. igel 
	-a|--account-number	Set the destination account by number
	-s|--source		Specify the source account if other than 303068756901. If not set script will look in IT Service Management Live account.
Example:
	$0 
"
exit 0
}

errusage(){
echo -e "usage: $0 [-i|--image <search term>] [-t|--target <target account>] [-s|--source <source account>] [-b|--band <play,work,live>] [-h|--help] [-c|--test]"
exit 2
}

##  Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--test") set -- "$@" "-H" ;;
    "--band") set -- "$@" "-b" ;;
    "--target") set -- "$@" "-t" ;;
    "--source") set -- "$@" "-s" ;;
    "--image") set -- "$@" "-i" ;;
    "--profile") set -- "$@" "-p" ;;
    "--account-number") set -- "$@" "-a" ;;
    *)        set -- "$@" "$arg"
  esac
done

##  Parse short options
OPTIND=1
while getopts "hHp:i:s:t:b:a:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    H)  TEST=true
        ;;
    b)  WhatBand=$OPTARG
        ;;
    i)  WhatImage=$OPTARG
        ;;
    s)  SrcAcct=$OPTARG
        ;;
    t)  WhatTargetAcct=$OPTARG
        ;;
    a)  WhatTargetAcctNumber=$OPTARG
        ;;
    p)  runprofile=$OPTARG
        ;;
    ?)  errusage >&2
        ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

# and here we go. Testing, or sharing from here on out.

#command substitution if using profile or not
if [ -n "$runprofile" ]; then
	awscommand="aws --profile $runprofile"
else
	awscommand="aws"
fi

#checking if stshelper script is on this system
if [[ ! $(type stshelper) ]]; then
	STSHELP=no
	echo -e "\nRunning without stshelper script. Consider installing it to make this a little easier\n"
else
	STSHELP=yes
fi

#this will check if you're logged in to itsm account and set a profile for it if so
cred_file=~/.aws/credentials
for i in `awk -v var="$SrcAcct" '$0~var' RS= ${cred_file} | grep aws_credentials_expiry | awk '{ print $NF }'`
do secs=`echo $(( ( ${i%%.*} - $(date -u +%s) ) / 60 ))`
        if [ ${secs} -gt "0" ]; then
                ITSMPROF=`awk -v var="$i" '$0~var' RS= ${cred_file} | head -1 | sed 's/[][]//g'`
        else
                echo "You are not logged in to account ${SrcAcct}, that hosts the image, attempting to log you in now..."
		echo "1 $ITSMPROF"
                ITSMPROF=`awk -v var="$i" '$0~var' RS= ${cred_file} | head -1 | sed 's/[][]//g'`
		echo "2 $ITSMPROF"
		if [[ $STSHELP == "yes" ]]; then
			stshelper ${ITSMPROF%%-*}
			wait
		else
			stsauth authenticate -f -l $ITSMPROF
			wait
		fi
	
#                echo "You are not logged in to the account that hosts the image, account number $SrcAcct"
#                exit 2
        fi
done

#finding the image first
if [[ "$WhatImage" =~ "ami-" ]]; then
	AMIID=$WhatImage
else #HERE need to make the command work no matter which profile is set to env
#	if [[ $("${awscommand}" ec2 describe-images --owners ${SrcAcct} --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text --profile $ITSMPROF | wc -l ) -eq "1" ]]; then
	if [[ $(aws ec2 describe-images --owners ${SrcAcct} --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text --profile $ITSMPROF | wc -l ) -eq "1" ]]; then
#		echo "step 1"
		AMIID=$(aws ec2 describe-images --owners ${SrcAcct} --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text --profile $ITSMPROF)
	elif [[ $(aws ec2 describe-images --owners ${SrcAcct} --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text --profile $ITSMPROF | wc -l ) -lt "1" ]]; then
#		echo "step 2"
		echo "You have an issue with your image, I did not find what you were looking for"
		exit 4
	elif [[ $(aws ec2 describe-images --owners ${SrcAcct} --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text --profile $ITSMPROF | wc -l ) -gt "1" ]]; then
#		echo "step 3"
		echo "You have an issue with your image, I found more than one. You will need to be more specific"
		exit 4
	fi
fi

#finding account number for the searched for account/band
if [ -z $WhatTargetAcctNumber ]; then
	if [ ${STSHELP} == "yes" ]; then
		if [[ $(stshelper -s ${WhatTargetAcct} | grep Account | grep -i ${WhatBand} | awk '{ print $NF }' | sed 's/[()]//g' | sort -u | wc -l ) -eq "1" ]]; then
			TargetAcctNumber=$(stshelper -s ${WhatTargetAcct} | grep Account | grep -i ${WhatBand} | awk '{ print $NF }' | sed 's/[()]//g' | sort -u)
		elif [[ $(stshelper -s ${WhatTargetAcct} | grep Account | grep -i ${WhatBand} | awk '{ print $NF }' | sed 's/[()]//g' | sort -u | wc -l ) -lt "1" ]]; then
			echo "You have an issue with your account search, I did not find that account"
			exit 3
		elif [[ $(stshelper -s ${WhatTargetAcct} | grep Account | grep -i ${WhatBand} | awk '{ print $NF }' | sed 's/[()]//g' | sort -u | wc -l ) -gt "1" ]]; then
			echo "You have an issue with your account search, I found too many and you need to be more specific"
			exit 3
		fi
	else
		if [[ $(awk -v var="$WhatTargetAcct" '$0~var' RS= ~/.aws/credentials | awk -v var="$WhatBand" '$0~var' RS= | grep account_id | awk '{ print $NF }' | wc -l ) -eq "1" ]]; then
			TargetAcctNumber=$(awk -v var="$WhatTargetAcct" '$0~var' RS= ~/.aws/credentials | awk -v var="$WhatBand" '$0~var' RS= | grep account_id | awk '{ print $NF }')
		elif [[ $(awk -v var="$WhatTargetAcct" '$0~var' RS= ~/.aws/credentials | awk -v var="$WhatBand" '$0~var' RS= | grep account_id | awk '{ print $NF }' | wc -l ) -lt "1" ]]; then
			echo "You don't have that profile in your $cred_file"
			exit 3
		elif [[ $(awk -v var="$WhatTargetAcct" '$0~var' RS= ~/.aws/credentials | awk -v var="$WhatBand" '$0~var' RS= | grep account_id | awk '{ print $NF }' | wc -l ) -gt "1" ]]; then
			echo "Unclear what account you wanted, consider adding the stshelper script and creating a list of possible roles"
			exit 3
		fi
	fi
else
	TargetAcctNumber=${WhatTargetAcctNumber}
fi
	

#if [ -n $TEST ]; then
if [[ $TEST == "true" ]]; then
echo ""
echo -e "Band searched for was $WhatBand"
echo -e "Image searched for was $WhatImage"
echo -e "Destination Account set was $TargetAcctNumber"
echo -e "Source Account set was $SrcAcct"
exit 0
fi

#checking if account already has access to the image
if [[ $(${awscommand} ec2 describe-image-attribute --image-id ${AMIID} --attribute launchPermission | grep ${TargetAcctNumber} ) ]]; then
#		echo "step 4"
	if [ -n $WhatTargetAcctNumber ]; then
		echo "The Image is already shared with ${WhatTargetAcctNumber}" 
	else
		echo "The Image is already shared with ${WhatTargetAcct}-${WhatBand}" 
	fi
	exit 0
fi

#adding target account to image attribute
${awscommand} ec2 modify-image-attribute --image-id ${AMIID} --launch-permission "Add=[{UserId=${TargetAcctNumber}}]"
#		echo "step 5"
	if [ -n "$WhatTargetAcctNumber" ]; then
		echo "Image ${AMIID} has been shared with ${WhatTargetAcctNumber}" 
	else
		echo "Image ${AMIID} has been shared with ${WhatTargetAcct}-${WhatBand}"
	fi
exit 0
