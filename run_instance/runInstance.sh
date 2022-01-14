#!/bin/bash
# runInstance.sh
##################################################
##
## This script will take a suggested image, a given
## volume size, instance type, and a file with tags
## and will launch instances
##
##################################################
##
## HERE
##  need to add a version section cause it keeps changing.
## 8/26 made changes to where region/az are set in the feed section cause it was after the subnet section resulting in wrong azs for instances
## 8/26 block device issues on the ami using feed
## 9/17 add "-v" option for if you want to see verbose, otherwise hide most of the output
## 

#setting some parameters

#WhatImage=
#WhatTargetAcct=
#WhatBand=
SubnetSearch=private # this needs to either be public or private. will set private as default and a flag to switch most likely
VOLSIZE=100
InstanceType=t2.micro
TagFile=tags
#KEYPAIR=~/.ssh/cloudops_test.pub
#KEYNAME=bbva-ea-default-${WhatBand}-key
region=us-east-1 
zone=a

TEST=FALSE

# temp files
tempUserData=/tmp/temp.user.data
tempFeedFile=/tmp/temp.feedfile

## functions. I love functions.

#help function
helptext="\
Usage: $0
	--help | -h		- This menu
	--test | -H		- Build command without launching instances
	--image | -i		- What image to base the new instance on, rhel or cent
	--account | -a		- Which account, i.e. igel
	--account-number | -A	- Specify the account by number
	--band | -b		- Which band to run this in, required when using --account flag
	--subnet | -s		- Public or Private subnet. Default is private, flag will select public
	--security-group | -S	- Security Group selection. Choices are: private, public, management, applicataion, storage
	--ip-address | -P	- Specify private ip address. Must be within the CIDR range of the subnet selected
	--volume-size | -v	- Size of EBS volume
	--instance-type | -I	- Instance type, i.e. t2.large
	--profile | -p		- The profile/account you want to build instances in; not required unless you're logged in to multiple accounts simultaneously
	--tags | -t		- File/path to file with required tags and values, in csv format
	--feed | -f		- Feed a csv file with names, tags, and pertinent info at one time. This supercedes the other options
"
errorhelptext="\
Usage: $0
	[--help|-h] [--test|-H] [--image|-i] [--account|-a] [--account-number|-A] [--band|-b] [--subnet|-s] [--security-group|-S] [--volume-size|-v] [--instance-type|-I] [--ip-address|-P] [--profile|-p] [--tags|-t] [--feed|-f]
"
usage () {
echo "$helptext"
exit
}
errusage () {
echo "$errorhelptext"
exit
}
	
# tiemstamp function
timestamp(){ date "+%Y-%m-%d %H:%M:%S.%2N" ; }

# date for the script
NowDate=$(date +%Y%m%d%H%M)

#log something already
LogFile=${WhatTargetAcct}.${WhatBand}.${InstanceType}.${WhatImage}.creation.${NowDate}


#HERE
#tags function
#tagfun () {
#if [ -f $TagFile ]; then
#echo "$(timestamp) - Found tags at $TagFile" | tee -a "$LogFile"
#TAGS=$(while IFS=";" read key value; do echo "{Key=$key,Value=$value}"; done < $TagFile | tr '\n' ',' | rev | cut -c 2- | rev)
#else
#echo "$(timestamp) - No tags file was found at $TagFile, please fix" | tee -a "$LogFile"
#exit
#fi
#} # end of tagfun function

tagfun () {
if [ -f $TagFile ]; then
echo "$(timestamp) - Found tags at $TagFile"

bbvaopsuuaa=$(grep -E "\<uuaa\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopsoperationalband=$(grep -E "\<operationalband\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopslogicalenvironment=$(grep -E "\<logicalenvironment\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaarchprojectname=$(grep -E "\<projectname\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaarchworkload=$(grep -E "\<workload\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopslineofbusiness=$(grep -E "\<lineofbusiness\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopslineofbusinesslevel2=$(grep -E "\<lineofbusinesslevel2\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaarchinitiative=$(grep -E "\<initiative\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopstechcontact=$(grep -E "\<techcontact\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopscreatedby=$(grep -E "\<createdby\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaisgpci=$(grep -E "\<pci\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaisgpii=$(grep -E "\<pii\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaisgsox=$(grep -E "\<sox\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaarchappcmdb=$(grep -E "\<appcmdb\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopsbackupplan=$(grep -E "\<backup\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopsinstancename=$(grep -E "\<instancename\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
HostName=$(grep -E "\<Name\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')
bbvaopsinstancescheduler=$(grep -E "\<instancescheduler\>" ${TagFile} | grep -vE "^#" | awk -F';' '{ print $2 }')

TAGtext="\
{Key=bbva-ops-uuaa,Value=$bbvaopsuuaa},\
{Key=bbva-ops-operationalband,Value=$bbvaopsoperationalband},\
{Key=bbva-ops-logicalenvironment,Value=$bbvaopslogicalenvironment},\
{Key=bbva-arch-projectname,Value=$bbvaarchprojectname},\
{Key=bbva-arch-workload,Value=$bbvaarchworkload},\
{Key=bbva-ops-lineofbusiness,Value=$bbvaopslineofbusiness},\
{Key=bbva-ops-lineofbusinesslevel2,Value=$bbvaopslineofbusinesslevel2},\
{Key=bbva-arch-initiative,Value=$bbvaarchinitiative},\
{Key=bbva-ops-techcontact,Value=$bbvaopstechcontact},\
{Key=bbva-ops-createdby,Value=$bbvaopscreatedby},\
{Key=bbva-isg-pci,Value=$bbvaisgpci},\
{Key=bbva-isg-pii,Value=$bbvaisgpii},\
{Key=bbva-isg-sox,Value=$bbvaisgsox},\
{Key=bbva-arch-appcmdb,Value=$bbvaarchappcmdb},\
{Key=bbva-ops-backup-plan,Value=$bbvaopsbackupplan},\
{Key=bbva-ops-instancename,Value=$bbvaopsinstancename},\
{Key=Name,Value=$bbvaopsinstancename},\
{Key=bbva-ops-instancescheduler,Value=$bbvaopsinstancescheduler}\
"

TAGtextEBS="\
{Key=bbva-ops-uuaa,Value=$bbvaopsuuaa},\
{Key=bbva-ops-operationalband,Value=$bbvaopsoperationalband},\
{Key=bbva-ops-logicalenvironment,Value=$bbvaopslogicalenvironment},\
{Key=bbva-arch-projectname,Value=$bbvaarchprojectname},\
{Key=bbva-arch-workload,Value=$bbvaarchworkload},\
{Key=bbva-ops-lineofbusiness,Value=$bbvaopslineofbusiness},\
{Key=bbva-ops-lineofbusinesslevel2,Value=$bbvaopslineofbusinesslevel2},\
{Key=bbva-arch-initiative,Value=$bbvaarchinitiative},\
{Key=bbva-ops-techcontact,Value=$bbvaopstechcontact},\
{Key=bbva-ops-createdby,Value=$bbvaopscreatedby},\
{Key=bbva-isg-pci,Value=$bbvaisgpci},\
{Key=bbva-isg-pii,Value=$bbvaisgpii},\
{Key=bbva-isg-sox,Value=$bbvaisgsox},\
{Key=bbva-arch-appcmdb,Value=$bbvaarchappcmdb}\
"
else
echo "$(timestamp) - No file was found at $TagFile, please fix by running \"$0 --generate\" to create initial tag file"
exit 3
fi
} # end of tagfun function

# function setting hostname
hostnamefun () {
#HostName=$(echo $TAGS | tr ' ' '\n' | grep Name | awk -F'=' '{ print $3 }')
HostName=$(echo $TAGS | awk -v var="Name" '$0~var' RS='{' | awk -F'=' '{ print $3 }' | sed -e 's/}//g' | sed -e '$d')
if [ -z "$HostName" ]; then
	echo -e "\nNo hostname was found in the tags file. You'll need to set a hostname with a tag = Name"
	exit
fi
} # end of hostnamefun function


# function to find source AMI
srcamifun () {
if [[ "$WhatImage" =~ "ami-" ]]; then
	SRCAMIID=$(${awscommand} ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageId, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text )
else
	SRCAMIID=$(${awscommand} ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text )
fi
wait
echo "source ami $SRCAMIID"
sleep 2
if [[ ! "$SRCAMIID" == "" ]]; then
	echo "$(timestamp) - The source image was found and shared to this acocunt. It's AMI-ID is $SRCAMIID" | tee -a "$LogFile"
else
	echo "$(timestamp) - The source image wasn't found. Attempting to call shareAMI.sh" | tee -a "$LogFile"
	AMIID=$(aws --profile 303068756901-ADFS-LIVE-ITOperations ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text )
	wait
	echo "Attempting to add ami-id $AMIID to the target account, $TARGETACCT"
	${HOME}/Nextcloud/homedir/scripts/aws/share_image/shareImage.sh -a ${TARGETACCT} -i "${AMIID}"
	wait
	if [[ "$WhatImage" =~ "ami-" ]]; then
		SRCAMIID=$(${awscommand} ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageId, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text )
	else
		SRCAMIID=$(${awscommand} ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text )
	fi
	if [[ ! "$SRCAMIID" == "" ]]; then
		echo "$(timestamp) - The source image was shared to this acocunt. It's AMI-ID is $SRCAMIID" | tee -a "$LogFile"
	else
		echo "$(timestamp) - Sharing the source image failed, this will need to be done manually before proceeding" | tee -a "$LogFile"
		exit
	fi
fi
} # end srcamifun function


# target account function
targetaccountfun () {
if [ -z $SPCACCT ]; then
	HowManyAcct=$(stshelper -s ${WhatTargetAcct} | grep Account | grep -i ${WhatBand} | awk '{ print $NF }' | sed 's/[()]//g' | sort -u | wc -l)
	
	if [[ "$HowManyAcct" -eq 1 ]]; then
	        TARGETACCT=$(stshelper -s ${WhatTargetAcct:0:3} | grep Account | grep -i ${WhatBand} | awk '{ print $NF }' | sed 's/[()]//g' | sort -u)
	elif [[ "$HowManyAcct" -eq 0 ]]; then
		echo "There were no accounts named ${WhatTargetAcct} for the ${WhatBand} band."
		exit
	else
		targetarray=($(for i in `stshelper -s ${WhatTargetAcct} | grep Account | grep -i ${WhatBand} | awk '{ print $NF }' | sed 's/[()]//g' | sort -u`; do grep $i ~/.aws/possibleroles ; done))
		count=0
		arrlength=${#targetarray[@]}
		if [[ "$arrlength" -eq 2 ]]; then
			tstacct=${targetarray[0]}
		elif [[ "$arrlength" -gt 2 ]]; then
			echo "your otions are:"
			for (( index=1; index<${#targetarray[@]}; index+=3 ))
			do
				echo "$((count+=1)) - ${targetarray[$index]}"
			done
			echo "There are several matching accounts, choose the approrpiate account:"
			read -n1 choice
			if [[ ! "$choice" -le "$count" ]]; then
				echo -e "\nThat was not a valid option."
				exit
			fi
			case $choice in
				1 ) ;;
				2 ) choice=$(($choice + 2 )) ;;
				3 ) choice=$(($choice + 4 )) ;;
				4 ) choice=$(($choice + 6 )) ;;
				5 ) choice=$(($choice + 8 )) ;;
				6 ) choice=$(($choice + 10 )) ;;
				* ) echo "There were too many choices, narrow your search options and run again"; exit ;;
			esac
			
			choice2=$(($choice + 1 ))
			echo -e "\nContinuing with ${targetarray[$choice]}"
			TARGETACCT=$(echo "${targetarray[$choice2]}" | sed -e 's/[()]//g')
		else
			echo "Something went wrong, please try again"
			exit
		fi
	fi
else
	TARGETACCT=$SPCACCT
fi
} # end of targetaccountfun function


# function to set subnet for new instance
subnetfun () {
if [[ $SubnetSearch =~ "subnet-" ]]; then
SubnetID=$SubnetSearch
else
subnetarray=($(${awscommand} ec2 describe-subnets --filters Name=availability-zone,Values=[${region}${zone}] Name=tag:Name,Values=[*${SubnetSearch}*] --query 'Subnets[].[SubnetId,AvailabilityZone]' | tr -d '\n' | sed -e 's/[] ,[]//g' | sed -e 's/"/ /g'))

count=0
arrlength=${#subnetarray[@]}
if [[ "$arrlength" -eq 2 ]]; then
	SubnetID=${subnetarray[0]}
elif [[ "$arrlength" -gt 2 ]]; then
	echo "your otions are:"
	for (( index=1; index<${#subnetarray[@]}; index+=2 ))
	do
		echo "$((count+=1)) - ${subnetarray[$index]}"
	done
	echo "which option do you choose?"
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
		6 ) choice=$(($choice + 5 )) ;;
		7 ) choice=$(($choice + 6 )) ;;
		8 ) choice=$(($choice + 7 )) ;;
		* ) echo "there are too many"; exit ;;
	esac
	
	choice2=$(($choice - 1 ))
	SubnetID=$(echo "${subnetarray[$choice2]}" | sed -e 's/[()]//g')
else
	echo "$(timestamp) - Something went badly and I couldn't find the subnet you were looking for..." | tee -a "$LogFile"
	exit 4
fi
fi

echo "$(timestamp) - Continuing with subnet $SubnetID" | tee -a "$LogFile"
} # end of subnetfun function


# security group function
sgfun () {
for val in "${SecGroup[@]}"; do
echo "$val"
case "$val" in
	private )
		SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*rivate* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
		;;
	management )
		SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*anagement* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
		;;
	application )
		SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*pplication* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
		;;
	public )
		SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*ublic* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
		;;
	storage )
		SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*torage* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
		;;
	sg* )
		SecurityGroup+=($val)
		;;
	*) echo -e "\nYour Security group option wasn't a valid choice.\nChoices are: private, public, management, application, and storage.\n\nPlease try again"; exit ;;
esac
done
} # end sgfun function


#function for creating device mapping file
devmapfun () {
DevName=$(${awscommand} ec2 describe-images --image-id ${SRCAMIID} --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[BlockDeviceMappings[].DeviceName]" --output text)
touch "$tempFile"
echo "\
[
    {
        \"DeviceName\": \"$DevName\",
        \"Ebs\": {
                \"Encrypted\": true,
                \"VolumeSize\": ${VOLSIZE}
        }
    }
]" > "$tempFile"
} # end of devmapfun function


# userdata function
userdatafun () {
touch ${tempUserData}
echo "\
#!/bin/bash
hostnamectl set-hostname --static ${HostName}
cd /tmp
export no_proxy=\"localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.0.0.0/8,logs.${region}.amazonaws.com,.s3.${region}.amazonaws.com,s3.${region}.amazonaws.com,.secretsmanager.${region}.amazonaws.com,.ec2messages.${region}.amazonaws.com,.ssm.${region}.amazonaws.com,.api.ecr.${region}.amazonaws.com,api.ecr.${region}.amazonaws.com,.ecs-telemetry.${region}.amazonaws.com,.ssmmessages.${region}.amazonaws.com,.ecs.${region}.amazonaws.com,.elasticloadbalancing.${region}.amazonaws.com,.monitoring.${region}.amazonaws.com,.ec2.${region}.amazonaws.com,.dkr.ecr.${region}.amazonaws.com,.ecs-agent.${region}.amazonaws.com,.monitoring.${region}.amazonaws.com,169.254.169.254,.internal,.bbvacompass.com,.compassbnk.com,secretsmanager.${region}.amazonaws.com,.s3.amazonaws.com,s3.amazonaws.com,dynamodb.${region}.amazonaws.com,.dynamodb.${region}.amazonaws.com,bitbucket.tools.live.cloud.bbvausa.com,artifactory.tools.live.cloud.bbvausa.com,crowd.tools.live.cloud.bbvausa.com,bitbucket.tools.work.cloud.bbvausa.com,artifactory.tools.work.cloud.bbvausa.com,crowd.tools.work.cloud.bbvausa.com,bitbucket.tools.play.cloud.bbvausa.com,artifactory.tools.play.cloud.bbvausa.com,crowd.tools.play.cloud.bbvausa.com\"
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent" > ${tempUserData}
} # end userdatafun function


CMDBUILD() {
if [ -n "$ipaddress" ]; then
${awscommand} ec2 run-instances --image-id $SRCAMIID --count 1 --instance-type $InstanceType --region ${region} --subnet-id ${SubnetID} --security-group-ids ${SecurityGroup[@]} --block-device-mappings 'DeviceName=/dev/sda1,Ebs={Encrypted=true,VolumeSize='"${VOLSIZE}"'}' --tag-specifications 'ResourceType=instance,Tags=['"${TAGS}"']' 'ResourceType=volume,Tags=['"${TAGS}"']' --user-data file://$tempUserData --private-ip-address ${ipaddress} --query 'Instances[].{NewInstance:InstanceId,NewPirvateIP:PrivateIpAddress,Status:StateReason.Code}' --iam-instance-profile Name=DefaultEC2Role --output table
else
${awscommand} ec2 run-instances --image-id $SRCAMIID --count 1 --instance-type $InstanceType --region ${region} --subnet-id ${SubnetID} --security-group-ids ${SecurityGroup[@]} --block-device-mappings 'DeviceName=/dev/sda1,Ebs={Encrypted=true,VolumeSize='"${VOLSIZE}"'}' --tag-specifications 'ResourceType=instance,Tags=['"${TAGS}"']' 'ResourceType=volume,Tags=['"${TAGS}"']' --user-data file://$tempUserData --query 'Instances[].{NewInstanceID:InstanceId,NewPrivateIP:PrivateIpAddress,Status:StateReason.Code}' --iam-instance-profile Name=DefaultEC2Role --output table
fi
}

CMDBUILDtest="\
${awscommand} ec2 run-instances --image-id $SRCAMIID --count 1 --instance-type $InstanceType --region ${region} --subnet-id ${SubnetID} --security-group-ids ${SecurityGroup[@]} --block-device-mappings file://$tempFile --tag-specifications 'ResourceType=instance,Tags=['"$TAGS"']' --user-data file://$tempUserData --query 'Instances[].{NewInstanceID:InstanceId,NewPrivateIP:PrivateIpAddress,Status:StateReason.Code}'"

sleep 1



# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--test") set -- "$@" "-H" ;;
    "--image") set -- "$@" "-i" ;;
    "--account") set -- "$@" "-a" ;;
    "--account-number") set -- "$@" "-A" ;;
    "--band") set -- "$@" "-b" ;;
    "--region") set -- "$@" "-r" ;;
    "--subnet") set -- "$@" "-s" ;;
    "--security-group") set -- "$@" "-S" ;;
#    "--zone") set -- "$@" "-z" ;;
    "--volume-size") set -- "$@" "-v" ;;
    "--instance-type") set -- "$@" "-I" ;;
    "--tags") set -- "$@" "-t" ;;
    "--profile") set -- "$@" "-p" ;;
    "--ip-address") set -- "$@" "-P" ;;
    "--feed") set -- "$@" "-f" ;;
    *)        set -- "$@" "$arg"
  esac
done


# Parse short options
OPTIND=1
while getopts "hHi:a:A:b:s:S:z:r:v:I:t:P:p:f:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    H)  TEST=TRUE
        ;;
    i)  WhatImage=$OPTARG
        ;;
    a)  WhatTargetAcct=$OPTARG
        ;;
    A)  SPCACCT=$OPTARG
        ;;
    b)  WhatBand=$OPTARG
        ;;
#    z)  zone=$OPTARG
#        ;;
#    r)  region=$OPTARG
    r)  while IFS='-' read country azregion az; do
	aznum=${az:0:1}
	region=$country-$azregion-$aznum
	azzone=${az:1:1}
	done < <(echo $WhatRegion)
        ;;
#    s)  SubnetSearch=public
    s)  SubnetSearch=$OPTARG
        ;;
    S)  SecGroup+=("$OPTARG")
        ;;
    v)  VOLSIZE=$OPTARG
        ;;
    I)  InstanceType=$OPTARG
        ;;
    t)  TagFile="$OPTARG"
        ;;
    p)  runprofile=$OPTARG
        ;;
    P)  ipaddress=$OPTARG
        ;;
    f)  FeedFile="$OPTARG"
        ;;
    ?)  errusage >&2
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

#grouping all in main
main () {
echo "$(timestamp) - Starting runInstance.sh script now" | tee -a "$LogFile"
echo "$(timestamp) - setting NowDate as $NowDate" | tee -a "$LogFile"
echo "going with $WhatImage for what image"

echo "$(timestamp) - Looking for tags..." | tee -a "$LogFile"
tagfun
wait

hostnamefun
wait

echo "$(timestamp) - Finding the target account" | tee -a "$LogFile"
targetaccountfun
wait

echo "$(timestamp) - Looking for the source ami" | tee -a "$LogFile"
if [[ "$WhatImage" =~ "ami-" ]]; then
	SRCAMIID="$WhatImage"
#	if [ -z "$SRCAMIID" ]; then
	if [[ ! $( aws ec2 describe-images --image-id ${WhatImage} --output text ) =~ "ami-" ]]; then
		srcamifun
	fi
else
	srcamifun
fi
wait

#echo "$(timestamp) - Checking if bbva default key is in place" | tee -a "$LogFile"
#keypairfun
#wait

echo "$(timestamp) - Finding subnet information" | tee -a "$LogFile"

if [ -n "$SubnetSearch" ]; then
	if [[ $SubnetSearch =~ "subnet-" ]]; then
		SubnetID=$SubnetSearch
	else
		SubnetID=$(${awscommand} ec2 describe-subnets --filters Name=availability-zone,Values=${region}${zone} Name=tag:Name,Values=[*${SubnetSearch}] --query 'Subnets[].SubnetId' --output text)
		wait
			if [ -z ${SubnetID} ]; then
				subnetfun
			wait
			fi
			echo "$(timestamp) - Using subnet $SubnetID" | tee -a "$LogFile"
	fi
else
		subnetfun
		wait
fi

echo "$(timestamp) - Finding security group information" | tee -a "$LogFile"
sgfun
wait

echo "$(timestamp) - finding devicename from ami" | tee -a "$LogFile"
devmapfun
wait

echo "$(timestamp) - Defining user data file" | tee -a "$LogFile"
userdatafun
wait


if [ $TEST == "FALSE" ]; then
	echo -e "$(timestamp) - Running the command now." | tee -a "$LogFile"
	(set -x; CMDBUILD) | tee -a "$LogFile"
	rm -f /tmp/temp.*
	exit
else
	echo -e "$(timestamp) - Command would have been:\n${CMDBUILDtest}" | tee -a "$LogFile"
	rm -f /tmp/temp.*
	exit
fi
} # end of main function

#actual step 1, is -f flag passed? if yes, go to else, if no, go to main
if [ -z "$FeedFile" ]; then
	main
else
# the -f flag was passed
touch ${tempFeedFile}
sed -e 's///g' < "${FeedFile}" > ${tempFeedFile}
FeedFileArray=($(grep -Ev "Name,Security|^#|^$" ${tempFeedFile}))
#FeedFileArray=($(grep -Ev "Name,Security|^#|^$" ${FeedFile}))

#break out the almost 30 fields
while IFS=',' read -r a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad; do

#command alias to capture if runprofile is in the feedfile
if [ -n "$h" ]; then
	awscommand="aws --profile $h"
else
	awscommand="aws"
fi

LogFile=batch.${f}.${g}.creation.${NowDate}

HostName="$a"

echo -e "\nBeginning $a now"

SecurityGroup=()

# finding security groups
echo -e "Setting SGs now"
SGStart=($(echo "$b" | awk '{split($0,b,";"); print b[1]" " b[2]" " b[3]" "b[4]" " b[5]}'))
for val in "${SGStart[@]}"; do
echo "$val"
case "$val" in
        priv* )
                SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*rivate* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        manag* )
                SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*anagement* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        applic* )
                SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*pplication* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        publ* )
                SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*ublic* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        stor* )
                SecurityGroup+=($(${awscommand} ec2 describe-security-groups --filters Name=group-name,Values=*torage* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
	sg* )
		SecurityGroup+=($val)
		;;
        *) echo -e "The SG option of $val was not a valid answer and will be ignored";;
esac
done
	
WhatRegion="$i"
#regionnum=$(( ${#WhatRegion} - 1 ))
#region="${WhatRegion:0:${regionnum}}"
#zone=${WhatRegion:${regionnum}}

while IFS='-' read country azregion az; do
#azcountry=$country
aznum=${az:0:1}
region=$country-$azregion-$aznum
zone=${az:1:1}
done < <(echo $WhatRegion)

# finding subnet
# function to set subnet for new instance
subnetfun2 () {
if [[ $SubnetSearch =~ "subnet-" ]]; then
SubnetID=$c
else
subnetarray=($(${awscommand} ec2 describe-subnets --filters Name=availability-zone,Values=[${region}${zone}] Name=tag:Name,Values=[*${c}*] --query 'Subnets[].[SubnetId,AvailabilityZone]' | tr -d '\n' | sed -e 's/[] ,[]//g' | sed -e 's/"/ /g'))

count=0
arrlength=${#subnetarray[@]}
if [[ "$arrlength" -eq 2 ]]; then
	SubnetID=${subnetarray[0]}
elif [[ "$arrlength" -gt 2 ]]; then
	echo "your otions are:"
	for (( index=1; index<${#subnetarray[@]}; index+=2 ))
	do
		echo "$((count+=1)) - ${subnetarray[$index]} ${subnetarray[$(($index - 1))]}"
	done
	echo "which option do you choose?"
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
		6 ) choice=$(($choice + 5 )) ;;
		7 ) choice=$(($choice + 6 )) ;;
		8 ) choice=$(($choice + 7 )) ;;
		* ) echo "there are too many"; exit ;;
	esac
	
	choice2=$(($choice - 1 ))
	SubnetID=$(echo "${subnetarray[$choice2]}" | sed -e 's/[()]//g')
else
	echo "$(timestamp) - Something went badly and I couldn't find the subnet you were looking for..." | tee -a "$LogFile"
	exit 4
fi
fi

echo "$(timestamp) - Continuing with subnet $SubnetID" | tee -a "$LogFile"
} # end of subnetfun2 function
echo -e "Setting Subnet"
if [ -n "$c" ]; then
	if [[ $c =~ "subnet-" ]]; then
		SubnetID=$c
	else
	        SubnetID=$(${awscommand} ec2 describe-subnets --filters Name=availability-zone,Values=${region}${zone} Name=tag:Name,Values=[*${c}] --query 'Subnets[].SubnetId' --output text)
	        wait
	        if [ -z ${SubnetID} ]; then
	                subnetfun2
	        wait
	        fi
	        echo "$(timestamp) - Using subnet $SubnetID" | tee -a "$LogFile"
	fi
else
        subnetfun2
        wait
fi

#general variables
echo -e "Gathering variables"
VOLSIZE="$d"
InstanceType="$e"
WhatImage="$f"
#passing "f" to srcamiid function
TARGETACCT="$g"
echo -e "Finding source ami"
if [[ "$WhatImage" =~ "ami-" ]]; then
	SRCAMIID="$WhatImage"
	if [[ ! $( aws ec2 describe-images --image-id ${SRCAMIID} --output text ) =~ "ami-" ]]; then
		srcamifun
	fi
else
	srcamifun
fi
runprofile="$h"
WhatBand="$p"

if [ -n "$j" ]; then
	ipaddress="$j"
fi
#k future 3
#l future 4

#tags
echo -e "Gathering tags"
bbvaopsinstancescheduler="$m"
bbvaopsuuaa="$n"
bbvaopsoperationalband="$o"
bbvaopslogicalenvironment="$p"
bbvaarchprojectname="$q"
bbvaarchworkload="$r"
bbvaopslineofbusiness="$s"
bbvaopslineofbusinesslevel2="$t"
bbvaarchinitiative="$u"
bbvaopstechcontact="$v"
bbvaopscreatedby="$w"
bbvaisgpci="$x"
bbvaisgpii="$y"
bbvaisgsox="$z"
bbvaarchappcmdb="$aa"
bbvaopsbackupplan="$ab"
bbvaopsinstancename="$a"

TAGtext="\
{Key=bbva-ops-uuaa,Value=$bbvaopsuuaa},\
{Key=bbva-ops-operationalband,Value=$bbvaopsoperationalband},\
{Key=bbva-ops-logicalenvironment,Value=$bbvaopslogicalenvironment},\
{Key=bbva-arch-projectname,Value=$bbvaarchprojectname},\
{Key=bbva-arch-workload,Value=$bbvaarchworkload},\
{Key=bbva-ops-lineofbusiness,Value=$bbvaopslineofbusiness},\
{Key=bbva-ops-lineofbusinesslevel2,Value=$bbvaopslineofbusinesslevel2},\
{Key=bbva-arch-initiative,Value=$bbvaarchinitiative},\
{Key=bbva-ops-techcontact,Value=$bbvaopstechcontact},\
{Key=bbva-ops-createdby,Value=$bbvaopscreatedby},\
{Key=bbva-isg-pci,Value=$bbvaisgpci},\
{Key=bbva-isg-pii,Value=$bbvaisgpii},\
{Key=bbva-isg-sox,Value=$bbvaisgsox},\
{Key=bbva-arch-appcmdb,Value=$bbvaarchappcmdb},\
{Key=bbva-ops-backup-plan,Value=$bbvaopsbackupplan},\
{Key=bbva-ops-instancename,Value=$bbvaopsinstancename},\
{Key=Name,Value=$bbvaopsinstancename},\
{Key=bbva-ops-instancescheduler,Value=$bbvaopsinstancescheduler}\
"

TAGtextEBS="\
{Key=bbva-ops-uuaa,Value=$bbvaopsuuaa},\
{Key=bbva-ops-operationalband,Value=$bbvaopsoperationalband},\
{Key=bbva-ops-logicalenvironment,Value=$bbvaopslogicalenvironment},\
{Key=bbva-arch-projectname,Value=$bbvaarchprojectname},\
{Key=bbva-arch-workload,Value=$bbvaarchworkload},\
{Key=bbva-ops-lineofbusiness,Value=$bbvaopslineofbusiness},\
{Key=bbva-ops-lineofbusinesslevel2,Value=$bbvaopslineofbusinesslevel2},\
{Key=bbva-arch-initiative,Value=$bbvaarchinitiative},\
{Key=bbva-ops-techcontact,Value=$bbvaopstechcontact},\
{Key=bbva-ops-createdby,Value=$bbvaopscreatedby},\
{Key=bbva-isg-pci,Value=$bbvaisgpci},\
{Key=bbva-isg-pii,Value=$bbvaisgpii},\
{Key=bbva-isg-sox,Value=$bbvaisgsox},\
{Key=bbva-arch-appcmdb,Value=$bbvaarchappcmdb}\
"

#block devices
#device name first
DevName=$(${awscommand} ec2 describe-images --image-id ${SRCAMIID} --query "Images[].[BlockDeviceMappings[].DeviceName]" --output text)
echo -e "Setting any additional block devices"
BlockDevice=()
BlockDevice+=("${VOLSIZE}}")

#extra devices
if [ -n "$ac" ]; then
SDBstart=($(echo "$ac" | awk -F';' '{ print $1" "$2 }'))
BlockDevice+=("DeviceName=/dev/xvdf,Ebs={Encrypted=true,VolumeSize=${SDBstart[0]},VolumeType=${SDBstart[1]}}")
fi

if [ -n "$ad" ]; then
SDCstart=($(echo "$ad" | awk -F';' '{ print $1" "$2 }'))
BlockDevice+=("DeviceName=/dev/xvdg,Ebs={Encrypted=true,VolumeSize=${SDCstart[0]},VolumeType=${SDCstart[1]}}")
fi

userdatafun


CMDBUILD() {
if [ -n "$ipaddress" ]; then
${awscommand} ec2 run-instances --image-id $SRCAMIID --count 1 --instance-type $InstanceType --region ${region} --subnet-id ${SubnetID} --security-group-ids ${SecurityGroup[@]} --block-device-mappings 'DeviceName='"${DevName}"',Ebs={Encrypted=true,VolumeSize='"${BlockDevice[@]}"'' --tag-specifications 'ResourceType=instance,Tags=['"${TAGtext}"']' 'ResourceType=volume,Tags=['"${TAGtextEBS}"']' --user-data file://$tempUserData --private-ip-address ${ipaddress} --query 'Instances[].{NewInstanceID:InstanceId,NewPrivateIP:PrivateIpAddress,Status:StateReason.Code}' --iam-instance-profile Name=DefaultEC2Role --output table
else
${awscommand} ec2 run-instances --image-id $SRCAMIID --count 1 --instance-type $InstanceType --region ${region} --subnet-id ${SubnetID} --security-group-ids ${SecurityGroup[@]} --block-device-mappings 'DeviceName='"${DevName}"',Ebs={Encrypted=true,VolumeSize='"${BlockDevice[@]}"'' --tag-specifications 'ResourceType=instance,Tags=['"${TAGtext}"']' 'ResourceType=volume,Tags=['"${TAGtextEBS}"']' --user-data file://$tempUserData --query 'Instances[].{NewInstanceID:InstanceId,NewPrivateIP:PrivateIpAddress,Status:StateReason.Code}' --iam-instance-profile Name=DefaultEC2Role --output table
fi
}

if [ $TEST == "FALSE" ]; then
echo -e "$(timestamp) - Running the command now\n\n" | tee -a "$LogFile"
(set -x; CMDBUILD) | tee -a "$LogFile"
rm -f /tmp/temp.*
else
echo -e "$(timestamp) - Command would have been:\n${CMDBUILDtest}" | tee -a "$LogFile"
rm -f /tmp/temp.*
fi

done < <(for i in ${!FeedFileArray[*]}; do echo "${FeedFileArray[$i]}"; done)
#end of feedfile portion

fi
