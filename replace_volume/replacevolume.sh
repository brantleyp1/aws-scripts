#!/bin/bash
# replacevolume.sh
#
# take a known instance id and a known volume
# and replace the volume with a given snapshot
# 
# look at the tags too, if you're not doing client vista you'll want to ajust
#


# change to the device as needed
DEVNAME=/dev/xvdf

#if you're using this for anything other than client vista for the mongo issue, use the correct instance ids for your case.
#pick a source from one of these:
#PrimaryReplicaNode0	10.14.7.59	i-026005235dc1e86d2
#SecondaryReplicaNode1	10.14.7.4	i-099ffa18cb82147ee
#SecondaryReplicaNode0	10.14.7.177	i-0aeb23ec9478ecceb

#pick a destination:
#CV-QA-PrimaryReplicaNode0	10.14.7.65	i-0d588af9c738a22c9 original volumeid vol-095a4b658249a1fac
#PrimaryReplicaNode0	10.14.7.218	i-007566a6c394fcba9 orig vol-002313b6b206c8d86
#10.14.7.142	i-00829bee489059abc

DESTINSID="i-00829bee489059abc"
SRCINSID="i-099ffa18cb82147ee"

echo "finding source volume to snapshot"

SRCVOLID=$(aws ec2 describe-instances --instance-ids ${SRCINSID} --query "Reservations[].Instances[].BlockDeviceMappings[?contains(DeviceName, \`${DEVNAME}\`) == \`true\`].Ebs[].VolumeId" --output text)

echo "taking snapshot of ${SRCVOLID}, will continue when complete.

This may take a while if a large volume!
"

NEWSNAPID=$(aws ec2 create-snapshot --volume-id ${SRCVOLID} --description "copying data volume for swapover - source ${SRCINSID}" --output text --query 'SnapshotId')

aws ec2 wait snapshot-completed --snapshot-id ${NEWSNAPID}
echo "snapshot ${NEWSNAPID} was created"

#stop the instance which makes swapping volume faster:
echo "stopping destination instance ${DESTINSID}"
aws ec2 stop-instances --instance-ids ${DESTINSID}
aws ec2 wait instance-stopped --instance-id ${DESTINSID}

#find the volumeid of the volume to replace:
echo "finding destination volume to replace"
DESTVOLID=$(aws ec2 describe-instances --instance-ids ${DESTINSID} --query "Reservations[].Instances[].BlockDeviceMappings[?contains(DeviceName, \`${DEVNAME}\`) == \`true\`].Ebs[].VolumeId" --output text)
echo "found volume ${DESTVOLID}"

#detach the volume:
echo "detaching volume from instance"
aws ec2 detach-volume --volume-id ${DESTVOLID}
aws ec2 wait volume-available --volume-id ${DESTVOLID}

#make new volume based on snapshot:
echo "making new volume based on snapshot"
NEWVOLID=$(aws ec2 create-volume --volume-type gp2 --size 400 --encrypted --tag-specifications 'ResourceType=volume,Tags=[{Key=bbva-ops-uuaa,Value=unkown},{Key=bbva-ops-operationalband,Value=work},{Key=bbva-ops-logicalenvironment,Value=test},{Key=bbva-arch-projectname,Value=saber},{Key=bbva-arch-workload,Value=saber},{Key=bbva-ops-lineofbusiness,Value=clientvista},{Key=bbva-ops-lineofbusinesslevel2,Value=clientvista},{Key=bbva-arch-initiative,Value=unkown},{Key=bbva-ops-techcontact,Value=clientvista},{Key=bbva-ops-createdby,Value=oso-unix},{Key=bbva-isg-pci,Value=no},{Key=bbva-isg-pii,Value=no},{Key=bbva-isg-sox,Value=no},{Key=bbva-arch-appcmdb,Value=unknown}]' --availability-zone us-east-1d --snapshot-id ${NEWSNAPID} --output text --query 'VolumeId')

echo "created volume ${NEWVOLID}"

aws ec2 wait volume-available --volume-id ${NEWVOLID}

#attach the volume:
echo "attaching new volume ${NEWVOLID} to destination instance"
aws ec2 attach-volume --volume-id ${NEWVOLID} --instance-id ${DESTINSID} --device ${DEVNAME}
aws ec2 wait volume-in-use --volume-id ${NEWVOLID}

#start the intance:
echo "starting destination instance ${DESTINSID} now, please wait"
aws ec2 start-instances --instance-ids ${DESTINSID}
aws ec2 wait instance-running --instance-id ${DESTINSID}

echo "should be complete now.
a snapshot of ${SRCVOLID} was used to create ${NEWVOLID} and attached to ${DESTINSID} as ${DEVNAME} and is now running.
"
exit
