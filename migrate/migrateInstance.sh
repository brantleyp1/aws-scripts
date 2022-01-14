#!/bin/bash
# NewmigrateInstance.sh
#
################################
## in orig account:
## I would need to create a key first
## then share that key with a key policy to the new account
## then copy the image with that key
## then share the new image to the account
## 
## then in the new account:
## launch new instances based on shared image
## not needed: create new image on new instance
## not needed: create new instance on new instance using local account keys
## 
## in orig account:
## remove first new image snapshots
## remove first new image
## remove second new image snapshots
## remove second new image
## remove key used to share
################################
## 

#setting some parameters

SubnetSearch=private
TEST=false
buildtags=false
turnOffIns=false
terminateIns=false
deleteAMI1=false
deleteAMI2=false
deleteKEY=false
rebootIns="no-"
includeUser=yes
#isEncrypted=no # dunno if this needs to be set here or not
migrateKeyExists=false
skipCopy=false
skipCreate=false
tempShareKey="alias/legacyMigration"

# temp files
tempUserData=/tmp/temp.user.data
temptagfile=/tmp/temp.tags.src
#TagFile=$temptagfile
tempKeyPolicy=/tmp/temp.key.policy

availabilityzone=us-east-1a
while IFS='-' read country azregion az; do
azcountry="$country"
region="$azregion"
aznum="${az:0:1}"
azzone="${az:1:1}"
done < <(echo "$availabilityzone")


## functions. I love functions.

#help function
## removing test for now, need to figure out how to impliment it
helptext="\
Usage: $0
        --help | -h             - This menu
        --generate | -g         - Build initial file containing tags of existing instance, it will open in vi to edit
        --instance | -i         - Required - source instance to be migrated
        --destination | -d      - Required(unless just generating tags) - the Destination profile/account you want to build instance in
        --profile | -p          - Required - the Source profile/account you want to copy instances from
        --subnet | -s           - Private subnet is default. Choices are: private, public, or subnet-XXX for a specific subnet
        --security-group | -S   - Security Group selection. Choices are: private, public, management, applicataion, storage, or sg-XXXX for specific group
        --az | -a               - Set Availability zone if different than us-east-1a, must be in this format, i.e. us-west-1a or eu-north-1b
        --tags | -t             - File/path to file with required tags and values, in csv format using = to differentiate Key and Value
        --clean | -c            - Delete AMIs created through this process and schedule key for deletion
        --ami-id | -I           - Provide the AMI to skip process of building new AMI on instance
        --encrypted-ami | -E	- Provide the AMI to skip process of copying the new AMI with migration key
        --reboot | -r           - Allow create-image to reboot instance, much faster but will cause interruption
        --turn-off | -o         - Stop instance after migration process
        --terminate | -O        - Terminate instance after migration process
        --windows | -w          - Disables user-data settings (for now, could be used to set powershell in the future)
"
errorhelptext="\
Usage: $0
        [--help|-h] [--generate|-g] [--instance|-i] [--destination|-d] [--profile|-p] [--clean|-c] [--subnet|-s] [--security-group|-S] [--az|-a] [--tags|-t] [--encrypted-ami|-E] [--reboot|-r] [--turn-off|-o] [--terminate|-O]
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
        # tiemstamp function
        timestamp(){ date -j "+%Y-%m-%d %H:%M:%S" ; }
        # futre date for script
        FutureDate=$(date -j -v+1m +%m-%d-%Y)
        # date for the script
        NowDate=$(date -j +%Y%m%d%H%M)
else
        # tiemstamp function
        timestamp(){ date "+%Y-%m-%d %H:%M:%S.%2N" ; }
        # futre date for script
        FutureDate=$(date --date='1 month' +%m-%d-%Y)
        # date for the script
        NowDate=$(date +%Y%m%d%H%M)
fi


#tags functions
buildtagfun () {
touch "${temptagfile}"

echo "#Tags for instance ${srcInsId} captured on ${NowDate}" > "${temptagfile}"

aws --profile "${srcprofile}" ec2 describe-tags --filters Name=resource-id,Values="${srcInsId}" --output text | awk '{ print $2"="$5 }' >> "${temptagfile}"

defTAGtext="
# The following are the required tags for EC2 instances:
#bbva-ops-uuaa
#bbva-ops-operationalband
#bbva-ops-logicalenvironment
#bbva-arch-projectname
#bbva-arch-workload
#bbva-ops-lineofbusiness
#bbva-ops-lineofbusinesslevel2
#bbva-arch-initiative
#bbva-ops-techcontact
#bbva-ops-createdby
#bbva-isg-pci
#bbva-isg-pii
#bbva-isg-sox
#bbva-arch-appcmdb
#bbva-ops-backup-plan
#bbva-ops-instancename
#Name
#bbva-ops-instancescheduler\
"
echo "$defTAGtext" >> "${temptagfile}"

echo "The currently set tags for instance ${srcInsId} has been captured in ${temptagfile}. Please review and make sure it has all correct and required tags."
vi "${temptagfile}"
exit 0
} # end of buildtagfun


tagfun () {
if [ -f "$temptagfile" ]; then
echo "$(timestamp) - Found tags at $temptagfile"
echo "Pulling correct tag values from $temptagfile"

bbvaopsuuaa=$(grep -E "\<uuaa\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopsoperationalband=$(grep -E "\<operationalband\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopslogicalenvironment=$(grep -E "\<logicalenvironment\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaarchprojectname=$(grep -E "\<projectname\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaarchworkload=$(grep -E "\<workload\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopslineofbusiness=$(grep -E "\<lineofbusiness\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopslineofbusinesslevel2=$(grep -E "\<lineofbusinesslevel2\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaarchinitiative=$(grep -E "\<initiative\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopstechcontact=$(grep -E "\<techcontact\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopscreatedby=$(grep -E "\<createdby\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaisgpci=$(grep -E "\<pci\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaisgpii=$(grep -E "\<pii\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaisgsox=$(grep -E "\<sox\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaarchappcmdb=$(grep -E "\<appcmdb\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopsbackupplan=$(grep -E "\<backup\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopsinstancename=$(grep -E "\<instancename\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
HostName=$(grep -E "\<Name\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')
bbvaopsinstancescheduler=$(grep -E "\<instancescheduler\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')

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
echo "$(timestamp) - No file was found at $temptagfile, please fix by running \"$0 --generate\" to create initial tag file"
exit 3
fi
} # end of tagfun function

# function setting hostname
hostnamefun () {
if [ -z "$HostName" ]; then
        echo -e "\nNo hostname was found in the tags file. You'll need to set a hostname with a tag = Name"
        exit 5
fi
} # end of hostnamefun function


# function to set subnet for new instance
subnetfun () {
if [[ "$SubnetSearch" =~ "subnet-" ]]; then
SubnetID="$SubnetSearch"
else
subnetarray=($(aws --profile "${destprofile}" ec2 describe-subnets --filters Name=availability-zone,Values=["${azcountry}"-"${region}"-"${aznum}""${azzone}"] Name=tag:Name,Values=[*${SubnetSearch}*] --query 'Subnets[].[SubnetId,AvailabilityZone]' | tr -d '\n' | sed -e 's/[] ,[]//g' | sed -e 's/"/ /g'))

count=0
arrlength="${#subnetarray[@]}"
if [[ "$arrlength" -eq 2 ]]; then
        SubnetID="${subnetarray[0]}"
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
        echo "$(timestamp) - Something went badly and I couldn't find the subnet you were looking for..."
        exit 4
fi
fi

echo "$(timestamp) - Continuing with subnet $SubnetID"
} # end of subnetfun function


# security group function
sgfun () {
for val in "${SecGroup[@]}"; do
echo "$val"
case "$val" in
        private )
                SecurityGroup+=($(aws --profile "${destprofile}" ec2 describe-security-groups --filters Name=group-name,Values=*rivate* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        management )
                SecurityGroup+=($(aws --profile "${destprofile}" ec2 describe-security-groups --filters Name=group-name,Values=*anagement* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        application )
                SecurityGroup+=($(aws --profile "${destprofile}" ec2 describe-security-groups --filters Name=group-name,Values=*pplication* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        public )
                SecurityGroup+=($(aws --profile "${destprofile}" ec2 describe-security-groups --filters Name=group-name,Values=*ublic* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        storage )
                SecurityGroup+=($(aws --profile "${destprofile}" ec2 describe-security-groups --filters Name=group-name,Values=*torage* --query "SecurityGroups[*].{ID:GroupId}" --output text | head -1))
                ;;
        sg* )
                SecurityGroup+=($val)
                ;;
        *) echo -e "\nYour Security group option wasn't a valid choice.\nChoices are: private, public, management, application, and storage.\n\nPlease try again"; exit ;;
esac
done
} # end sgfun function


# userdata function
userdatafun () {
touch "${tempUserData}"
echo "\
#!/bin/bash
hostnamectl set-hostname --static ${HostName}
cd /tmp
export no_proxy=\"localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.0.0.0/8,logs.us-east-1.amazonaws.com,.s3.us-east-1.amazonaws.com,s3.us-east-1.amazonaws.com,.secretsmanager.us-east-1.amazonaws.com,.ec2messages.us-east-1.amazonaws.com,.ssm.us-east-1.amazonaws.com,.api.ecr.us-east-1.amazonaws.com,api.ecr.us-east-1.amazonaws.com,.ecs-telemetry.us-east-1.amazonaws.com,.ssmmessages.us-east-1.amazonaws.com,.ecs.us-east-1.amazonaws.com,.elasticloadbalancing.us-east-1.amazonaws.com,.monitoring.us-east-1.amazonaws.com,.ec2.us-east-1.amazonaws.com,.dkr.ecr.us-east-1.amazonaws.com,.ecs-agent.us-east-1.amazonaws.com,.monitoring.us-east-1.amazonaws.com,169.254.169.254,.internal,.bbvacompass.com,.compassbnk.com,secretsmanager.us-east-1.amazonaws.com,.s3.amazonaws.com,s3.amazonaws.com,dynamodb.us-east-1.amazonaws.com,.dynamodb.us-east-1.amazonaws.com,bitbucket.tools.live.cloud.bbvausa.com,artifactory.tools.live.cloud.bbvausa.com,crowd.tools.live.cloud.bbvausa.com,bitbucket.tools.work.cloud.bbvausa.com,artifactory.tools.work.cloud.bbvausa.com,crowd.tools.work.cloud.bbvausa.com,bitbucket.tools.play.cloud.bbvausa.com,artifactory.tools.play.cloud.bbvausa.com,crowd.tools.play.cloud.bbvausa.com\"
yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sed -i '/Service/a Environment=\"no_proxy=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.0.0.0/8,logs.us-east-1.amazonaws.com,.s3.us-east-1.amazonaws.com,s3.us-east-1.amazonaws.com,.secretsmanager.us-east-1.amazonaws.com,.ec2messages.us-east-1.amazonaws.com,.ssm.us-east-1.amazonaws.com,.api.ecr.us-east-1.amazonaws.com,api.ecr.us-east-1.amazonaws.com,.ecs-telemetry.us-east-1.amazonaws.com,.ssmmessages.us-east-1.amazonaws.com,.ecs.us-east-1.amazonaws.com,.elasticloadbalancing.us-east-1.amazonaws.com,.monitoring.us-east-1.amazonaws.com,.ec2.us-east-1.amazonaws.com,.dkr.ecr.us-east-1.amazonaws.com,.ecs-agent.us-east-1.amazonaws.com,.monitoring.us-east-1.amazonaws.com,169.254.169.254,.internal,.bbvacompass.com,.compassbnk.com,secretsmanager.us-east-1.amazonaws.com,.s3.amazonaws.com,s3.amazonaws.com,dynamodb.us-east-1.amazonaws.com,.dynamodb.us-east-1.amazonaws.com\"' /etc/systemd/system/amazon-ssm-agent.service
systemctl daemon-reload
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent" > "${tempUserData}"
} # end userdatafun function

#fuction to create ami based on existing instance
createAMIfun () {
NewImageId=$(aws --profile "${srcprofile}" ec2 create-image --instance-id "${srcInsId}" --${rebootIns}reboot --name "migration-ami-${HostName}_${NowDate}" --description "creating ami for migrating ${srcInsId} to new account - delete after ${FutureDate}" --output text)
OrigNewImageId="$NewImageId"
echo "Beginning taking image of ${srcInsId} with the ${rebootIns}reboot flag - new Image ID is ${NewImageId}
This may take several minutes."
aws --profile "${srcprofile}" ec2 wait image-available --image-id "${NewImageId}"
if [[ $(aws --profile "${srcprofile}" ec2 describe-images --image-id "${NewImageId}" --query 'Images[].StateReason[].Code' --output text) =~ "Error" ]]; then
	echo -e "\nSomething failed creating the Image. If this happens again you may need to check your access."
	exit 253
fi
if [[ ! $(aws --profile "${srcprofile}" ec2 describe-images --image-id "${NewImageId}" --query 'Images[].State' --output text) == "available" ]]; then
        echo "Image not available yet, will sleep for a few minutes then try again. Be patient..."
        sleep 180
        aws --profile "${srcprofile}" ec2 wait image-available --image-id "${NewImageId}"
        if [[ ! $(aws --profile "${srcprofile}" ec2 describe-images --image-id "${NewImageId}" --query 'Images[].State' --output text) == "available" ]]; then
                echo -e "\nThe new image is taking a long time to complete. The script will end now and you'll need to manually check the new image then try the script again, but feeding it the image.\nTo check the image, you can run:\n\naws --profile ${srcprofile} ec2 describe-images --image-id ${NewImageId} --query 'Images[].State' --output text\n\nWhen it says available, rerun this script with \"-I ${NewImageId}\" flag to skip the image build portion."
                exit 127
        fi
fi
copyAMIfun
} # end of createAMIfun


# copy image fuction to encrypt with new key
copyAMIfun () {
if [[ "$skipCopy" == "false" ]]; then
	if [[ "$isEncrypted" =~ "True" ]]; then
		if [[ "$migrateKeyExists" == "false" ]]; then
			migrateKeyfun
		else
			migrateKeyunDelete
		fi
	        echo "One or more of the volumes attached to ${srcInsId} was encrypted and some extra steps are needed. Please be patient."
	        OrigNewImageId="$NewImageId"
	        NewImageId2=$(aws --profile "${srcprofile}" ec2 copy-image --description "migrating encrypted ami ${NewImageId}" --kms-key-id "${tempShareKey}" --encrypted --name migrateAMI_"${NewImageId}" --source-image-id "${NewImageId}" --source-region us-east-1 --output text)
	        echo "We have created a new AMI ${NewImageId2} based on the AMI we just took in order to share it with encrypted snapshots."
	        NewImageId="${NewImageId2}"
	fi
	aws --profile "${srcprofile}" ec2 wait image-available --image-id "${NewImageId}"
	if [[ ! $(aws --profile "${srcprofile}" ec2 describe-images --image-id "${NewImageId}" --query 'Images[].State' --output text) == "available" ]]; then
	        echo "Image not available yet, will sleep for a few minutes then try again. Be patient..."
	        sleep 180
	        aws --profile "${srcprofile}" ec2 wait image-available --image-id "${NewImageId}"
	        if [[ ! $(aws --profile "${srcprofile}" ec2 describe-images --image-id "${NewImageId}" --query 'Images[].State' --output text) == "available" ]]; then
	                echo -e "\nThe new image is taking a long time to complete. The script will end now and you'll need to manually check the new image then try the script again, but feeding it the image.\nTo check the image, you can run:\n\naws --profile ${srcprofile} ec2 describe-images --image-id ${NewImageId} --query 'Images[].State' --output text\n\nWhen it says available, rerun this script with \"-E ${NewImageId}\" flag to skip the image build portion."
	                exit 128
	        fi
	fi
fi
} # end of copyAMIfun


#share ami function
shareAMIfun () {
if [[ ! "$srcprofile" == "$destprofile" ]]; then
	if [[ "$isEncrypted" =~ "True" ]]; then
		if [[ "$migrateKeyExists" == "TRUE" ]]; then
			migrateKeyunDelete
			echo -e "$(timestamp) - Sharing image now"
			aws --profile "${srcprofile}" ec2 modify-image-attribute --image-id "${NewImageId}" --launch-permission "Add=[{UserId=${DestinationAccountNumber}}]"
		else
			migrateKeyfun
			echo -e "$(timestamp) - Sharing image now"
			aws --profile "${srcprofile}" ec2 modify-image-attribute --image-id "${NewImageId}" --launch-permission "Add=[{UserId=${DestinationAccountNumber}}]"
		fi
	else
		echo -e "$(timestamp) - Sharing image now"
		aws --profile "${srcprofile}" ec2 modify-image-attribute --image-id "${NewImageId}" --launch-permission "Add=[{UserId=${DestinationAccountNumber}}]"
	fi
		
fi
} # end of shareAMIfun

#stop ami function
insstopfun () {
if [[ "$turnOffIns" == "TRUE" ]]; then
        echo "Stopping ${srcInsId} now..."
        aws --profile "${srcprofile}" ec2 stop-instances --instance-ids "${srcInsId}"
        aws --profile "${srcprofile}" ec2 wait instance-stopped --instance-id "${srcInsId}"
        echo "Instance ${srcInsId} is stopped"
fi
} # end of insstopfun

#stop ami function
instermfun () {
if [[ "$terminateIns" == "TRUE" ]]; then
        echo "Terminating ${srcInsId} now..."
        aws --profile "${srcprofile}" ec2 terminate-instances --instance-ids "${srcInsId}"
        aws --profile "${srcprofile}" ec2 wait instance-terminated --instance-id "${srcInsId}"
        echo "Instance ${srcInsId} is terminated"
fi
} # end of instermfun

# key policy function to build temp key
keyPolicyfun () {
rm -f "${tempKeyPolicy}"
touch "${tempKeyPolicy}"
keyPolicyText="\
{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Sid\": \"Enable IAM User Permissions\",
            \"Effect\": \"Allow\",
            \"Principal\": {
                \"AWS\": \"arn:aws:iam::${SourceAccountNumber}:root\"
            },
            \"Action\": \"kms:*\",
            \"Resource\": \"*\"
        },
        {
            \"Sid\": \"Allow access for Key Administrators\",
            \"Effect\": \"Allow\",
            \"Principal\": {
                \"AWS\": \"arn:aws:iam::${SourceAccountNumber}:role/ADFS-${SourceAccountBand}-${SourceAccountRole}\"
            },
            \"Action\": [
                \"kms:Create*\",
                \"kms:Describe*\",
                \"kms:Enable*\",
                \"kms:List*\",
                \"kms:Put*\",
                \"kms:Update*\",
                \"kms:Revoke*\",
                \"kms:Disable*\",
                \"kms:Get*\",
                \"kms:Delete*\",
                \"kms:TagResource\",
                \"kms:UntagResource\",
                \"kms:ScheduleKeyDeletion\",
                \"kms:CancelKeyDeletion\"
            ],
            \"Resource\": \"*\"
        },
        {
            \"Sid\": \"Allow use of the key\",
            \"Effect\": \"Allow\",
            \"Principal\": {
                \"AWS\": [
                    \"arn:aws:iam::${SourceAccountNumber}:role/ADFS-${SourceAccountBand}-${SourceAccountRole}\",
                    \"arn:aws:iam::${DestinationAccountNumber}:root\"
                ]
            },
            \"Action\": [
                \"kms:Encrypt\",
                \"kms:Decrypt\",
                \"kms:ReEncrypt*\",
                \"kms:GenerateDataKey*\",
                \"kms:DescribeKey\"
            ],
            \"Resource\": \"*\"
        },
        {
            \"Sid\": \"Allow attachment of persistent resources\",
            \"Effect\": \"Allow\",
            \"Principal\": {
                \"AWS\": [
                    \"arn:aws:iam::${SourceAccountNumber}:role/ADFS-${SourceAccountBand}-${SourceAccountRole}\",
                    \"arn:aws:iam::${DestinationAccountNumber}:root\"
                ]
            },
            \"Action\": [
                \"kms:CreateGrant\",
                \"kms:ListGrants\",
                \"kms:RevokeGrant\"
            ],
            \"Resource\": \"*\",
            \"Condition\": {
                \"Bool\": {
                    \"kms:GrantIsForAWSResource\": \"true\"
                }
            }
        }
    ]
}"
echo "$keyPolicyText" > "${tempKeyPolicy}"
} # end of keyPolicyfun

# function to create temp key for sharing
migrateKeyfun () {
if [[ "$migrateKeyExists" == "false" ]]; then
	keyPolicyfun
	echo "Creating Legacy Migration Key for sharing encrypted AMIs"
	migratekeyarn=$(aws --profile "${srcprofile}" kms create-key --policy file://"${tempKeyPolicy}" --description "temp key to share AMI from ${srcprofile} to ${destprofile}" --key-usage ENCRYPT_DECRYPT --customer-master-key-spec SYMMETRIC_DEFAULT --tags TagKey=bbva-ops-uuaa,TagValue=na TagKey=bbva-ops-operationalband,TagValue=na TagKey=bbva-ops-logicalenvironment,TagValue=na TagKey=bbva-arch-projectname,TagValue=na TagKey=bbva-arch-workload,TagValue=na TagKey=bbva-ops-lineofbusiness,TagValue=cloudops TagKey=bbva-ops-lineofbusinesslevel2,TagValue=cloudops TagKey=bbva-arch-initiative,TagValue=na TagKey=bbva-ops-techcontact,TagValue=cloudops TagKey=bbva-ops-createdby,TagValue=cloudops TagKey=bbva-isg-pci,TagValue=no TagKey=bbva-isg-pii,TagValue=no TagKey=bbva-isg-sox,TagValue=no TagKey=bbva-arch-appcmdb,TagValue=na --query KeyMetadata.Arn --output text)
	aws --profile "${srcprofile}" kms create-alias --alias-name "${tempShareKey}" --target-key-id "${migratekeyarn}"
fi
if $( ! aws --profile "${srcprofile}" kms describe-key --key-id "${tempShareKey}" > /dev/null 2>&1 ); then
	echo "Creating Migration key failed. The script will fail now and you'll need to create a KMS key and add the destination account to it before you can proceed.
After manually creating the key, give it an alias called \"${tempShareKey}\" and run this script again."
	exit 253
else
	echo "Creating ${tempShareKey} was successful. This key will be valid for 2 weeks."
	migrateKeyExists=TRUE
fi
} # end of migrateKeyfun 


# function to remove the deletion schedule key for sharing
migrateKeyunDelete () {
if [[ $(aws --profile "${srcprofile}" kms describe-key --key-id "${tempShareKey}" --query KeyMetadata.DeletionDate) == "null" ]]; then
	echo "${tempShareKey} is not scheduled for deletion, proceeding to next step"
else
	aws --profile "${srcprofile}" kms cancel-key-deletion --key-id $(aws --profile "${srcprofile}" kms describe-key --key-id "${tempShareKey}" --query KeyMetadata.KeyId --output text)
	aws --profile "${srcprofile}" kms enable-key --key-id $(aws --profile "${srcprofile}" kms describe-key --key-id "${tempShareKey}" --query KeyMetadata.KeyId --output text)
	echo "Deletion of ${tempShareKey} was cancelled so the image could be shared."
fi
} # end of migrateKeyunDelete

#clean up amis and keys if requested
deleteAMIfun1 () {
if [[ "$deleteAMI1" == "TRUE" ]]; then
	echo -e "\nCleaning up the initial AMI..."
	snaparray=($(aws --profile "${srcprofile}" ec2 describe-images --image-ids "${OrigNewImageId}" --query 'Images[].BlockDeviceMappings[].Ebs[].SnapshotId' --output text))
	aws --profile "${srcprofile}" ec2 deregister-image --image-id "${OrigNewImageId}"
	for i in ${snaparray}; do aws --profile "${srcprofile}" ec2 delete-snapshot --snapshot-id "$i"; done
fi
} # end of deleteAMIfun1 

deleteAMIfun2 () {
if [[ "$deleteAMI2" == "TRUE" ]]; then
	echo -e "\nCleaning up the encrypted copy of the AMI..."
	snaparray=($(aws --profile "${srcprofile}" ec2 describe-images --image-ids "${NewImageId}" --query 'Images[].BlockDeviceMappings[].Ebs[].SnapshotId' --output text))
	aws --profile "${srcprofile}" ec2 deregister-image --image-id "${NewImageId}"
	for i in ${snaparray}; do aws --profile "${srcprofile}" ec2 delete-snapshot --snapshot-id $i; done
fi
} # end of deleteAMIfun2 

deleteKEYfun () {
tempShareKeyArn=$(aws kms list-aliases --output text | grep "${tempShareKey}" | awk '{ print $NF }')
if [[ "$deleteKEY" == "TRUE" ]]; then
	echo -e "\nCleaning up the Legacy Migration Key. It will be available for 2 weeks."
	aws --profile "${srcprofile}" kms schedule-key-deletion --key-id "${tempShareKeyArn}" --pending-window-in-days 14
fi
} # end of deleteKEYfun 

# fucntion blockdevicefun to set any block devices found in ami to encrypt
blockdevicefun () {
blockdevicearray=($(aws --profile "${destprofile}" ec2 describe-images --image-ids "${NewImageId}" --query 'Images[].BlockDeviceMappings[].DeviceName' --output text))
BlockDeviceMap=$(for i in "${!blockdevicearray[@]}";
        do echo "DeviceName=${blockdevicearray[$i]},Ebs={Encrypted=true}"
done | tr '\n' ' ')
} # end of blockdevicefun

CMDBUILD() {
if [[ "$includeUser" == "yes" ]]; then
aws --profile "${destprofile}" ec2 run-instances --image-id "${NewImageId}" --count 1 --instance-type "$InstanceType" --region "${azcountry}"-"${region}"-"${aznum}" --subnet-id "${SubnetID}" --security-group-ids "${SecurityGroup[@]}" --block-device-mappings ${BlockDeviceMap} --tag-specifications 'ResourceType=instance,Tags=['"${TAGtext}"']' 'ResourceType=volume,Tags=['"${TAGtextEBS}"']' --user-data file://$tempUserData --query 'Instances[].{NewInstance:InstanceId,NewPrivateIp:PrivateIpAddress,CurrentState:StateReason.Code}' --output table
else
aws --profile "${destprofile}" ec2 run-instances --image-id "${NewImageId}" --count 1 --instance-type "$InstanceType" --region "${azcountry}"-"${region}"-"${aznum}" --subnet-id "${SubnetID}" --security-group-ids "${SecurityGroup[@]}" --block-device-mappings ${BlockDeviceMap} --tag-specifications 'ResourceType=instance,Tags=['"${TAGtext}"']' 'ResourceType=volume,Tags=['"${TAGtextEBS}"']' --query 'Instances[].{NewInstance:InstanceId,NewPrivateIp:PrivateIpAddress,CurrentState:StateReason.Code}' --output table
fi
}


# Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--test") set -- "$@" "-H" ;;
    "--instance") set -- "$@" "-i" ;;
    "--destination") set -- "$@" "-d" ;;
    "--subnet") set -- "$@" "-s" ;;
    "--security-group") set -- "$@" "-S" ;;
    "--ami-id") set -- "$@" "-I" ;;
    "--tags") set -- "$@" "-t" ;;
    "--az") set -- "$@" "-a" ;;
    "--profile") set -- "$@" "-p" ;;
    "--generate") set -- "$@" "-g" ;;
    "--turn-off") set -- "$@" "-o" ;;
    "--terminate") set -- "$@" "-O" ;;
    "--reboot") set -- "$@" "-r" ;;
    "--clean") set -- "$@" "-c" ;;
    "--windows") set -- "$@" "-w" ;;
    *)        set -- "$@" "$arg"
  esac
done

# Parse short options
OPTIND=1
while getopts "hHi:E:s:S:groOcI:t:wd:p:a:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    H)  TEST=TRUE
        ;;
    i)  srcInsId=$OPTARG
        ;;
    a)  availabilityzone=$OPTARG
        ;;
    I)  NewImageId=$OPTARG
	skipCreate=TRUE
        ;;
    E)  NewImageId=$OPTARG
	skipCreate=TRUE
	skipCopy=TRUE
        ;;
    g)  buildtags=TRUE
        ;;
    o)  turnOffIns=TRUE
        ;;
    O)  terminateIns=TRUE
        ;;
    r)  rebootIns=""
        ;;
    s)  SubnetSearch=$OPTARG
        ;;
    S)  SecGroup+=("$OPTARG")
        ;;
    t)  temptagfile=$OPTARG
        ;;
    w)  includeUser=no
        ;;
    d)  destprofile=$OPTARG
        ;;
    p)  srcprofile=$OPTARG
        ;;
    c)  deleteAMI1=TRUE
	deleteAMI2=TRUE
	deleteKEY=TRUE
        ;;
    ?)  errusage >&2
        ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

if [ -z "${srcInsId}" ]; then
        echo "You need to supply the Instnace-ID for the instance you want to migrate"
        exit 7
fi
if [ -z "$srcprofile" ]; then
        echo "You need to provide the account the instance currently exists in."
        exit 9
fi

if srcaliasname=$(aws --profile "${srcprofile}" iam list-account-aliases --query AccountAliases --output text 2> /dev/null); then
        echo -e "\nSource account is: $srcaliasname"
else
        echo -e "\nYou're not logged in to the source account, attempting to log you in using stshelper"
        stshelper -p ${srcprofile:0:12}
fi
# finding target account info based on srcprofile
while IFS='-' read acct a band role; do
SourceAccountNumber="${acct}"
SourceAccountBand="${band}"
SourceAccountRole="${role}"
done < <(echo "${srcprofile}")

# finding destination account info based on destprofile
while IFS='-' read acct a band role; do
DestinationAccountNumber="${acct}"
DestinationAccountBand="${band}"
DestinationAccountRole="${role}"
done < <(echo "${destprofile}")

if [[ "$buildtags" == "TRUE" ]]; then
        buildtagfun
fi

if [ -z "$destprofile" ]; then
        echo "You need to provide the account the instance will be migrated to."
        exit 11
fi

if destaliasname=$(aws --profile "${destprofile}" iam list-account-aliases --query AccountAliases --output text 2> /dev/null); then
        echo -e "\nDestination account is: $destaliasname"
else
        echo -e "\nYou're not logged in to the destination account, attempting to log you in using stshelper"
        stshelper -p ${destprofile:0:12}
fi

#gathering size of existing instance
InstanceType=$(aws --profile "${srcprofile}" ec2 describe-instances --instance-ids "${srcInsId}" --query 'Reservations[].Instances[].InstanceType' --output text)

# checking if src instance has encrypted volume(s)
isEncrypted=$(aws --profile "${srcprofile}" ec2 describe-volumes --volume-ids $(aws --profile "${srcprofile}" ec2 describe-instances --instance-ids "${srcInsId}" --query 'Reservations[].Instances[].BlockDeviceMappings[].Ebs[].VolumeId' --output text) --output text --query 'Volumes[].Encrypted')
if [[ "$isEncrypted" =~ "True" ]]; then
	echo -e "\nYour instance has encrypted volume(s) and will require extra steps to compelte."
fi

# checking if migration key exists
if $( aws --profile "${srcprofile}" kms describe-key --key-id "${tempShareKey}" > /dev/null 2>&1 ); then
	echo -e "\nLegacy Migration key already exists."
	migrateKeyExists=TRUE
else
	echo -e "\nLegacy Migration key doesn't exist but will be created in a minute."
	migrateKeyExists=false
fi

#grouping all in main
main () {
echo "$(timestamp) - Starting migrateInstance.sh script now"
echo "$(timestamp) - setting NowDate as $NowDate"

echo "$(timestamp) - Looking for tags..."
tagfun
wait

hostnamefun
wait


echo "$(timestamp) - Finding subnet information"

if [ -n "$SubnetSearch" ]; then
        if [[ "$SubnetSearch" =~ "subnet-" ]]; then
                SubnetID="$SubnetSearch"
        else
                SubnetID=$(aws --profile "${destprofile}" ec2 describe-subnets --filters Name=availability-zone,Values="${azcountry}"-"${region}"-"${aznum}""${azzone}" Name=tag:Name,Values=[*${SubnetSearch}] --query 'Subnets[].SubnetId' --output text)
                wait
                        if [ -z "${SubnetID}" ]; then
                                subnetfun
                        wait
                        fi
                        echo "$(timestamp) - Using subnet $SubnetID"
        fi
else
                subnetfun
                wait
fi

echo "$(timestamp) - Finding security group information"
sgfun
wait

echo "$(timestamp) - Defining user data file"
userdatafun
wait


if [ "$TEST" == "false" ]; then
        echo -e "$(timestamp) - Running the command now."
	if [[ "$skipCreate" == "false" ]]; then
	        echo -e "$(timestamp) - Starting image creation now"
	        createAMIfun
	else
		if [[ "$isEncrypted" =~ "True" ]]; then
			copyAMIfun
		fi
        fi
        shareAMIfun
        blockdevicefun
        wait
        (set -x; CMDBUILD)
        if [[ "$turnOffIns" == "TRUE" ]]; then
                insstopfun
        fi
        if [[ "$terminateIns" == "TRUE" ]]; then
                instermfun
        fi
	if [[ "$deleteAMI1" == "TRUE" ]]; then
		deleteAMIfun1
	fi
	if [[ "$deleteAMI2" == "TRUE" ]]; then
		deleteAMIfun2
	fi
	if [[ "$deleteKEY" == "TRUE" ]]; then
		deleteKEYfun
	fi
        #rm -f /tmp/temp.u*
        exit
#else
#        echo -e "$(timestamp) - Command would have been:\n${CMDBUILDtest}"
#       rm -f /tmp/temp.*
#        exit
fi
} # end of main function

main

