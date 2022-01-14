# runInstanceDR.sh && createAmiDR.sh

## Purpose

Create quick AMIs of DR tested instances and then launch instances for DR tests.

## Synopsis

For DR there are a few instances which have to have AMIs created, which isn't hard, then instances launched from those AMIs. The tags are annoying and the time to create the AMIs is never fun, so these scripts will take a quick AMI noting the existing tags. 

A few tags are edited, i.e. environment is set to DR, and for the AMI "-DR" is added for the name tag, then removed for launch.

It grabs the Instance type for the existing instance for the AMI, then removes that tag for running.

## Example

`./createAmiDR.sh -f list_of_instances`

Will take a flat file list of instances running, will create AMIs with existing tags and capture instance type for use when running.

`./createAmiDR.sh -i i-12321425555`

Will take the instance listed and create an AMI with tags attached.

`./runInstance.sh -i ami-12312455`

Will build a single instance based on the listed image. It will automatically assign the tags that are attached to the AMI, and will pull the Instance Type from the tags. It will assume you want to build in a VPC containing "DR", which will also base the subnet info and security group(s) for the instance(s). The Subnet and Security Group can be manually specified, but it should work for most needs.

`./runInstance.sh -f list_of_images`

Will build an instance for each instance listed in the flat file. It will use the tags assigned to the AMI including instance type. It will assume you want to build in a VPC containing "DR", which will also base the subnet info and security group(s) for the instance(s). 

## Options

### runInstanceDr.sh

`--help | -h`	- This menu

`--image | -i`	- What image to base the new instance on, rhel or cent

`--subnet | -s`	- Public or Private subnet. Default is private, flag will select public

`--security-group | -S`	- Security Group selection. Choices are: private, public, management, applicataion, storage

`--profile | -p`	- Pass AWS profile if you're signed in to multiple accounts simultaneously

`--feed | -f`	- Feed a flat file with AMI ID(s) to launch instances from

### createAmiDR.sh

`--help | -h`	- This menu

`--instance | -i`	- What instance to base the AMI on

`--profile | -p`	- Pass AWS profile if you're signed in to multiple accounts simultaneously

`--feed | -f`	- Feed a flat file with Instance ID(s) to create AMIs from

`--reboot | -r`	- Optional - Use Carefully - will cause instance to reboot during AMI creation. Faster, but disruptive

## Example Flat Files

### runInstanceDR.sh

`cat create_amis`

> i-00b005e51a6ed97b3
> i-044b415c73766e69a

### createAmiDR.sh

`cat need_to_launch`

> ami-075aa96384e53323b
> ami-03f1f0cedcd47ba9d
