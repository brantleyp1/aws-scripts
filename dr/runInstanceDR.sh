#!/bin/bash
# runInstanceDR.sh
##################################################
##
## this is a modified runInstance script used to launch
## DR instances from DR amis
## 
## there are none of the normal options, it uses the tags applied 
## to the AMI to apply to the instance
##
##################################################
##
## HERE
## TASK are for modfying for DR
## 

#setting some parameters

#TASK need to update for just DR
SubnetSearch=private # this needs to either be public or private. will set private as default and a flag to switch most likely
region=us-east-1 
zone=b

# temp files
tempUserData=/tmp/temp.user.data
tempFeedFile=/tmp/temp.feedfile

## functions. I love functions.

#help function
helptext="\
Usage: $0
	--help | -h		- This menu
	--image | -i		- What image to base the new instance on, rhel or cent
	--subnet | -s		- Private subnet is default, but you may specify either Public, or a SubnetID i.e. subnet-12345
	--security-group | -S	- Security Group selection. Choices are: private, public, management, applicataion, storage, or specific i.e. sg-12344556
	--volume-size | -v	- Size of EBS volume
	--instance-type | -I	- Instance type, i.e. t2.large
	--profile | -p		- The profile/account you want to build instances in; not required unless you're logged in to multiple accounts simultaneously
	--feed | -f		- Feed a csv file with just AMI IDs and Instance Types for the instances you want launched. It will take tags, volume info and default security group info from the AMI
"
errorhelptext="\
Usage: $0
	[--help|-h] [--image|-i] [--subnet|-s] [--security-group|-S] [--volume-size|-v] [--instance-type|-I] [--profile|-p] [--feed|-f]
"
usage () {
echo "$helptext"
exit
}
errusage () {
echo "$errorhelptext"
exit
}
	
# date for the script
NowDate=$(date +%Y%m%d)


tagfun () {
tagarray=($(${awscommand} ec2 describe-images --image-id ${AmiId} --query 'Images[].Tags' --output text | awk -F$'\t' '{ print "{Key="$1",Value="$2"}" }'))
#tagarray=($(${awscommand} ec2 describe-images --image-id ${AmiId} --query 'Images[].Tags' --output text | awk -F$'\t' "{ print \"Key=\"\$1\",Value='\"\$2\"'\" }"))
# set var HostName
for i in ${!tagarray[@]}; do
        if [[ "${tagarray[$i]}" =~ "Key=Name" ]]; then
                HostName=$(echo ${tagarray[$i]} | awk -F'=' '{ print $3 }' | sed "s/[{}]//g" | awk -F'-DR' '{ print $1 }')
        fi
	if [[ "${tagarray[$i]}" =~ "Key=bbva-dr-instancetype" ]]; then
		InstanceType=$(echo ${tagarray[$i]} | awk -F'=' '{ print $3 }' | sed "s/[{}]//g")
		unset tagarray[$i]
	fi
done
#making text of array
tagtext=$(echo ${tagarray[*]} | tr ' ' ',')
} # end of tagfun function

#find DR VPC
VpcId=$(aws ec2 describe-vpcs --query 'Vpcs[].VpcId' --filter Name=tag:Name,Values=[*DR*] --output text)

# function to set subnet for new instance
subnetfun () {
if [[ "$SubnetSearch" =~ "subnet-" ]]; then
	SubnetID=${SubnetSearch}
else
	SubnetID=$(aws ec2 describe-subnets --filters Name=availability-zone,Values=${region}${zone} Name=vpc-id,Values=${VpcId} Name=tag:Name,Values=*PRIVATE* --query 'Subnets[].SubnetId' --output text)
	if [ -z "$SubnetID" ]; then
		SubnetID=$(aws ec2 describe-subnets --filters Name=availability-zone,Values=${region}${zone} Name=vpc-id,Values=${VpcId} Name=tag:Name,Values=*rivate* --query 'Subnets[].SubnetId' --output text)
	fi
	if [ -z "$SubnetID" ]; then
		echo "Cannot find a \"Private\" Subnet in ${VpcId}. Please specify the Subnet manually."
		exit
	fi
fi
if [ -z "$SubnetID" ]; then
	echo "Cannot find a \"Private\" Subnet in ${VpcId}. Please specify the Subnet manually."
	exit
fi
} # end of subnetfun function


# security group function
sgfun () {
SecurityGroup=($(aws ec2 describe-security-groups --filter Name=vpc-id,Values=${VpcId} --query 'SecurityGroups[].GroupId' --output text))
} # end sgfun function


#function for creating device mapping file
devmapfun () {
DeviceArray=($(aws ec2 describe-images --image-id ${AmiId} --query 'Images[*].BlockDeviceMappings[*].[DeviceName,Ebs.VolumeType,Ebs.Encrypted,Ebs.VolumeSize]' --output text))

if [[ "${#DeviceArray[*]}" = 4 ]]; then
#	if [[ "${DeviceArray[1]}" == "gp2" ]]; then
#		BlockDevMap=";DeviceName=${DeviceArray[0]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[3]}};"
#	else
		BlockDevMap=(";DeviceName=${DeviceArray[0]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[3]},VolumeType=${DeviceArray[1]}};")
#	fi
elif [[ "${#DeviceArray[*]}" = 8 ]]; then
	BlockDevMap=(";DeviceName=${DeviceArray[0]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[3]},VolumeType=${DeviceArray[1]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[4]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[7]},VolumeType=${DeviceArray[5]}};")
elif [[ "${#DeviceArray[*]}" = 12 ]]; then
	BlockDevMap=(";DeviceName=${DeviceArray[0]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[3]},VolumeType=${DeviceArray[1]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[4]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[7]},VolumeType=${DeviceArray[5]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[8]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[11]},VolumeType=${DeviceArray[9]}};")
elif [[ "${#DeviceArray[*]}" = 16 ]]; then
	BlockDevMap=(";DeviceName=${DeviceArray[0]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[3]},VolumeType=${DeviceArray[1]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[4]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[7]},VolumeType=${DeviceArray[5]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[8]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[11]},VolumeType=${DeviceArray[9]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[12]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[14]},VolumeType=${DeviceArray[13]}};")
elif [[ "${#DeviceArray[*]}" = 20 ]]; then
	BlockDevMap=(";DeviceName=${DeviceArray[0]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[3]},VolumeType=${DeviceArray[1]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[4]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[7]},VolumeType=${DeviceArray[5]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[8]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[11]},VolumeType=${DeviceArray[9]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[12]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[14]},VolumeType=${DeviceArray[13]}};")
	BlockDevMap+=(";DeviceName=${DeviceArray[16]},Ebs={Encrypted=true,VolumeSize=${DeviceArray[18]},VolumeType=${DeviceArray[17]}};")
else
	echo "There are too many block devices attached to the AMI and this script can only support 5. Contact Brantley... Sorry..."
	exit
fi
#convert to blockdevtext
#BlockDevText=$(echo ${BlockDevMap[@]} | tr ';' \')
BlockDevText=$(echo ${BlockDevMap[@]} | tr -d ';')
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
${awscommand} ec2 run-instances --image-id $AmiId --count 1 --instance-type $InstanceType --region ${region} --subnet-id ${SubnetID} --security-group-ids ${SecurityGroup[@]} --block-device-mappings ${BlockDevText} --tag-specifications 'ResourceType=instance,Tags=['"${tagtext}"']' 'ResourceType=volume,Tags=['"${tagtext}"']' --user-data file://$tempUserData --query 'Instances[].{NewInstanceID:InstanceId,NewPrivateIP:PrivateIpAddress,Status:StateReason.Code}' --output table
}

sleep 1


# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--image") set -- "$@" "-i" ;;
    "--region") set -- "$@" "-r" ;;
    "--subnet") set -- "$@" "-s" ;;
    "--security-group") set -- "$@" "-S" ;;
    "--profile") set -- "$@" "-p" ;;
    "--feed") set -- "$@" "-f" ;;
    *)        set -- "$@" "$arg"
  esac
done


# Parse short options
OPTIND=1
while getopts "hi:s:S:r:p:f:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    i)  AmiId=$OPTARG
        ;;
    r)  while IFS='-' read country azregion az; do
	aznum=${az:0:1}
	region=$country-$azregion-$aznum
	azzone=${az:1:1}
	done < <(echo $WhatRegion)
        ;;
    s)  SubnetSearch=$OPTARG
        ;;
    S)  SecGroup+=("$OPTARG")
        ;;
    p)  runprofile=$OPTARG
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
echo "Starting runInstance.sh script now" 
echo "setting NowDate as $NowDate" 
echo "going with $AmiId for the image"

echo "Looking for tags..." 
tagfun
wait

echo "Finding subnet information" 

if [ -n "$SubnetSearch" ]; then
	if [[ $SubnetSearch =~ "subnet-" ]]; then
		SubnetID=$SubnetSearch
	else
		SubnetID=$(${awscommand} ec2 describe-subnets --filters Name=availability-zone,Values=${region}${zone} Name=tag:Name,Values=[*${SubnetSearch}*] --query 'Subnets[].SubnetId' --output text)
		wait
			if [ -z ${SubnetID} ]; then
				subnetfun
			wait
			fi
			echo "Using subnet $SubnetID" 
	fi
else
		subnetfun
		wait
fi

echo "Finding security group information" 
sgfun
wait

echo "finding devicenames from ami" 
devmapfun
wait

echo "Defining user data file" 
userdatafun
wait


echo -e "Running the command now." 
(set -x; CMDBUILD)
#rm -f /tmp/temp.*
} # end of main function


if [ -z "$FeedFile" ]; then
	main
else
#        feedarray=($(egrep -v "^#|^$" ${FeedFile}))
        feedarray=($(cat ${FeedFile}))
        for i in ${feedarray[@]}; do
                AmiId="$i"
                main "$AmiId"
        done
fi
exit
