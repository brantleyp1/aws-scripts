# My aws scripts

## Purpose

A while back I was required to handle a lot of AWS operations, at the time I wasn't familiar with terraform, so most of these scripts came out of a need to easily/scriptably handle AWS but not by just having a list of aws cli scripts to copy/paste.

## Synopsis

Most of these scripts can probably be done with straight terraform at this point, but a few really are helpful. I'll update this readme when time permits, but most of the scripts are very self explanatory.

Example of where one of these scripts might be easier/faster than terraform or cloudformation: with the `terminateInstance.sh`, you can feed a list of specific instances to terminate, and can specify if you want to take an ami first.

## Options

Most of the scripts have their own README, I'll try to go through and add/fix them.

All of the scripts have a help and some options, something like this:

A list of options, i.e.:
	[ --help|-h ] [ --instance-id|-i ] [ --profile|-p ] [ --snapshot|-s ] [ --force|-f]

with a long list of them, i.e.:
	--help|-h		Print this help menu

	--instance-id|-i	Instance ID of the ami to be deleted

	--profile|-p		Provide the profile if logged in to multiple accounts simultaneously

	--backup|-b		Take backup AMI of instance before terminating

	--force|-f		Answer yes, useful for scripted terminations. Will create AMI automatically unless --no-backup is passed

## List of scripts

- SG_ports
  - Create or modify a security group
- changesize
  - quickly convert small to xlarge or whatever
- deleteAmi
  - delete AMI and any associated snapshots
- describe-account
  - quickly learn everything possible about an account
- dr
  - slightly altered versions of createAmi and runInstnace scripts used to create AMIs and instances in a DR vpc
- loadbalancer
  - setup ALB
- migrate
  - migrate an instance between accounts
- replace_volume
  - specific need to replace a volume or attach an extra volume for swap/etc
- run_instance
  - launch new instances, can be run as a one-off or feed a csv. the tags are from an old position, but are left for examples
- share_image
  - share AMI between accounts
- ssm
  - Ansible code to deploy ssm agent to systems that don't have it built into the AMI
- start-stop **
  - just another way to start or stop an existing instance. left in for example sake
- terminate
  - terminate instance(s) with an optional snapshot taken before termination. Can be run as one-liner or fed a csv of instance IDs

\*\* This script can be replaced by a function. Exmaple of a quick restart function I use:
```
    ec2restart () {
    aws ec2 stop-instances --instance-ids $@
    echo "stopping instance $@"
    aws ec2 wait instance-stopped --instance-id $@
    echo "restarting instance $@"
    aws ec2 start-instances --instance-ids $@
    aws ec2 wait instance-running --instance-id $@
    echo "instance $@ has been restarted"
    }
```

## File structure

```bash
README.md
SG_ports
├── buildsecgroup.sh
└── cap2.csv
changesize
├── changeEc2Size.sh
└── list.csv
deleteAmi
├── README.md
├── deleteAmi.sh
├── list
└── tmp
describe-account
├── README.md
└── temp
dr
├── README.md
├── createAmiDR.sh
└── runInstanceDR.sh
loadbalancer
└── loadBalancer.sh
migrate
├── README.md
├── migrateInstance.sh
├── sample.key.policy
└── userdata
replace_volume
├── README.md
└── replacevolume.sh
run_instance
├── README.md
├── example.csv
├── run.csv
├── runInstance.sh
└── sample.tags
share_image
├── README.md
└── shareImage.sh
ssm
├── deployssm.yaml
└── sessionmanager-bundle.zip
start-stop
└── startstop.sh
terminate
├── README.md
├── sample.list
└── terminateInstance.sh
```
