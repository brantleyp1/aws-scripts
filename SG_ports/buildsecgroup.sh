#!/bin/bash
#
################
#
# NOTE!!! This script will most likely not work on legacy accounts, it assumes the VPC is built correctly
# and that it is tagged and named appropriately. It will fail if it can't find a VPC named similarly to the 
# account. 
#
# To find the list of VPCs run: aws ec2 describe-vpcs --query 'Vpcs[*][Tags[?Key==`Name`] | [0].Value, VpcId, CidrBlock]' --output table
#
# This script will parse a given csv file of ports and cidr ranges for custom security groups.
# you'll need to know the account name, i.e. netcashdemo, the band, i.e. play, and a name for
# the security group, i.e. spainaccess. These cannot contain spaces or capital letters.
#
# The group description can contain spaces or capitol letters and will need to be encased in "'s
#
# example of the csv file:
# Type,Protocol,Port,Source,Cidr,Description
# Custom TCP,TCP,3205,Custom,10.5.44.134/32,actifio
# Custom TCP,TCP,5106,Custom,10.5.44.134/32,actifio - Connector
#
################
#
# TODO stuff
# 

#variables to be set on command line:

## name of the security group, i.e. spainaccess
#NAME=
## i.e. netcashdemo
#ACCT=
## i.e. play
#BAND=
## this is something you set, "Allow Spain admin access"
#GRPDESC=""
TEST=false
EXISTS=false

## usage functions
usage(){
echo "
usage: $0
	-h|--help		Print this help file
	-t|--test		Test your settings before you commit
	-e|--exist		Update an existing security group with new rules
	-f|--file		Set the path to the csv file
	-a|--account		Set the Account, i.e. netcashdemo
	-b|--band		Set the band, i.e. play
	-n|--name		Set the name of the security group, i.e. spainaccess
	-d|--description	Set a description for the security group, i.e. \"Allow Spain admin access\"
"
exit 0
}

errusage(){
echo -e "usage: $0 [-f|--file /path/to/file] [-a|--account <name>] [-b|--band <play,work,live>] [-n|name <name of security group>] [-d|--description <\"good description\">] [-e|--exist] [-h|--help] [-t|--test]"
exit 2
}

##  Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--file") set -- "$@" "-f" ;;
    "--exist") set -- "$@" "-e" ;;
    "--account") set -- "$@" "-a" ;;
    "--band") set -- "$@" "-b" ;;
    "--name") set -- "$@" "-n" ;;
    "--description") set -- "$@" "-d" ;;
    "--test") set -- "$@" "-t" ;;
    "--profile") set -- "$@" "-p" ;;
    *)        set -- "$@" "$arg"
  esac
done

##  Parse short options
OPTIND=1
while getopts "htf:a:b:n:d:e:p:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    f)  FILE=$OPTARG
        ;;
    e)  GRPID=$OPTARG
	EXISTS=true
        ;;
    a)  ACCT=$OPTARG
        ;;
    b)  BAND=$OPTARG
        ;;
    n)  NAME=$OPTARG
        ;;
    d)  GRPDESC2="$OPTARG"
        ;;
    t)  TEST=true
        ;;
    p)  runprofile="$OPTARG"
        ;;
    ?)  errorusage >&2
        ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

#command alias
if [ -n "$runprofile" ]; then
        awscommand="aws --profile $runprofile"
else
        awscommand="aws"
fi

if [ -z $NAME ]; then
	echo -e "\nWhat name would you like to give this security group, i.e. spainaccess?\n"
	read -p "Name: " NAME
fi
if [ -z $ACCT ]; then
	echo -e "\nWhat Account is this security group for, i.e. netcashdemo?\n"
	read -p "Account: " ACCT
fi
if [ -z $BAND ]; then
	echo -e "\nWhat lifecycle band is this security group for, i.e. play?\n"
	read -p "Band: " BAND
fi
if [ -z "$GRPDESC2" ]; then
	echo -e "\nWhat is a good description for this security group, i.e. \"Allow Spain admin access\"?\n"
	read -p "Description: " GRPDESC2
        GRPDESC=$(echo "$GRPDESC2")
else
        GRPDESC=$(echo "$GRPDESC2")
fi

# Setting VPCID and allowing for multiples or if not found
VPCID=$(${awscommand} ec2 describe-vpcs --filter Name=tag:Name,Values=[$ACCT*] --output text --query 'Vpcs[].VpcId')
if [ $(echo "$VPCID" | wc | awk '{ print $2 }') -ne 1 ]; then
	vpcarray=($(${awscommand} ec2 describe-vpcs --query 'Vpcs[].[VpcId,Tags[?Key==`Name`].Value]' --filter Name=tag:Name,Values=[*] | tr -d '\n' | sed -e 's/[] ,[]//g' | sed -e 's/"/ /g'))
	count=0
	arrlength=${#vpcarray[@]}
	if [[ "$arrlength" -eq 2 ]]; then
		VPCID=${vpcarray[0]}
	elif [[ "$arrlength" -gt 2 ]]; then
	echo -e "\nI couldn't find a VPC with a name of $ACCT, but I found some others. Your otions are:"
	for (( index=1; index<${#vpcarray[@]}; index+=2 ))
	do
		echo "$((count+=1)) - ${vpcarray[$index]}"
	done
	echo "Select which VPC name to continue..."
	read -n1 choice
	if [[ ! "$choice" -le "$count" ]]; then
		echo -e "\nYou didn't pick a valid number"
		exit
	fi
	case $choice in
		1 ) ;;
		2 ) choice=$(($choice + 1 )) ;;
		3 ) choice=$(($choice + 2 )) ;;
		4 ) choice=$(($choice + 3 )) ;;
		5 ) choice=$(($choice + 4 )) ;;
		* ) echo -e "\nThere are too many VPCs, please run \"aws ec2 describe-vpcs --query 'Vpcs[*][Tags[?Key==\`Name\`] | [0].Value, VpcId, CidrBlock]' --output table\""; exit ;;
	esac
		
	choice2=$(($choice - 1 ))
	echo -e "\nContinuing with ${vpcarray[$choice]}"
	sleep 1
	VPCID=${vpcarray[$choice2]}
	else
		echo -e "\nNot sure this account was built correctly, you need to run this command manually to see if there are any named VPCs:\n\"aws ec2 describe-vpcs --query 'Vpcs[*][Tags[?Key==\`Name\`] | [0].Value, VpcId, CidrBlock]' --output table\""
		exit
	fi

fi

# script starts now, don't make changes unless you're sure of what you're doing
if [ -z $FILE ]; then
	echo -e "\nYou need to specify a csv file to continue.\n\nFile: "
	read $FILE
fi
if [ ! -e $FILE ]; then
	echo -e "\nThe path you entered for a file was invalid or I don't have access to the file, please check the file and try again"
	return
fi
# processing FILE to remove dumb characters
sed 's///g' $FILE | grep -vE "^#" > temp.$FILE
FILE=temp.${FILE}

#setting group name for later use
GRPNAME=sg.${ACCT}.${BAND}-1.${NAME}

#if [ -n $TEST ]; then
if [ $TEST == "true" ]; then
	echo -e "FILE is set to $FILE"
	echo -e "ACCT is set to $ACCT"
	echo -e "BAND is set to $BAND"
	echo -e "NAME is set to $NAME"
	echo -e "GRPDESC is set to $GRPDESC"
	echo -e "GRPNAME is set to $GRPNAME"
	if [ $EXISTS == "false" ]; then
		echo -e "You would create a security group like:"
		echo -e "VPCID=\$(aws ec2 describe-vpcs --filter Name=tag:Name,Values=[$ACCT*] --output text --query 'Vpcs[].VpcId')"
		echo -e "GRPID=\$(aws ec2 create-security-group --group-name $GRPNAME --description \"${GRPDESC}\" --vpc-id ${VPCID} --output text)"
	else
		echo -e "You would use existing group found by:"
		echo -e "GRPID=\$(aws ec2 describe-security-groups --query 'SecurityGroups[?contains(VpcId, \`$VPCID\`) == \`true\`]' --query 'SecurityGroups[?contains(GroupName, \`$NAME\`) == \`true\`].GroupId' --output text)"
	fi
	echo -e "The while loop would have looked like:"
	while IFS=, read -r A B C D E F; do
	echo -e "${awscommand} ec2 authorize-security-group-ingress --group-id $GRPID --ip-permissions IpProtocol=${B},FromPort=${C},ToPort=${C},IpRanges='[{CidrIp=${E},Description=${F}}]'"
	done < <(grep -v Protocol $FILE)
	rm $FILE
	exit 0
fi

# finding the VPC to use, should be the one with the account name in it
#VPCID=$(${awscommand} ec2 describe-vpcs --filter Name=tag:Name,Values=[$ACCT*] --output text --query 'Vpcs[].VpcId')

# creating the group and capturing the ID output for later use
if [ $EXISTS == "false" ]; then
GRPID=$(${awscommand} ec2 create-security-group --group-name $GRPNAME --description "$GRPDESC" --vpc-id $VPCID --output text)
echo -e "\nCreated Security Group: $GRPID\n"
else
GRPID=$(${awscommand} ec2 describe-security-groups --query 'SecurityGroups[?contains(VpcId, `'"$VPCID"'`) == `true`]' --query 'SecurityGroups[?contains(GroupName, `'"$NAME"'`) == `true`].GroupId' --output text)
echo -e "\nUsing existing Security Group: $GRPID\n"
fi

# adding rules to the group we just created
while IFS=, read -r A B C D E F; do
${awscommand} ec2 authorize-security-group-ingress --group-id $GRPID --ip-permissions IpProtocol=$B,FromPort=$C,ToPort=$C,IpRanges='[{CidrIp='"$E"',Description='"$F"'}]'
done < <(grep -v Protocol $FILE)
rm $FILE
exit 0
