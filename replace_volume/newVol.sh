#!/bin/bash

if [ -z "$1" ]; then
	echo "You must supply an instance id"
	exit
fi

InsId=$1
DevName="/dev/xvdi"

NewVolId=$(aws ec2 create-volume --volume-type io1 --size 15 --encrypted --iops 500 --tag-specifications 'ResourceType=volume,Tags=[{Key=bbva-ops-uuaa,Value=unkown},{Key=bbva-ops-operationalband,Value=live},{Key=bbva-ops-logicalenvironment,Value=prod},{Key=bbva-arch-projectname,Value=saber},{Key=bbva-arch-workload,Value=saber},{Key=bbva-ops-lineofbusiness,Value=clientvista},{Key=bbva-ops-lineofbusinesslevel2,Value=clientvista},{Key=bbva-arch-initiative,Value=unkown},{Key=bbva-ops-techcontact,Value=clientvista},{Key=bbva-ops-createdby,Value=oso-unix},{Key=bbva-isg-pci,Value=no},{Key=bbva-isg-pii,Value=no},{Key=bbva-isg-sox,Value=no},{Key=bbva-arch-appcmdb,Value=unknown}]' --availability-zone us-east-1d --query 'VolumeId' --output text)

aws ec2 wait volume-available --volume-id ${NewVolId}

aws ec2 attach-volume --volume-id ${NewVolId} --instance-id ${InsId} --device ${DevName}

aws ec2 wait volume-in-use --volume-id ${NewVolId}

cat << EOF


You'll need to run on the instance(s):

mkswap ${DevName}
echo "${DevName} none swap sw 0 0" >> /etc/fstab
mount -a
swapon ${DevName}


EOF

exit
