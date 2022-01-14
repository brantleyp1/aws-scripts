# terminateInstance.sh

## Purpose

Quickly "delete" an Instance and it's attached EBS volumes.

## Synopsis

This script removes any termination protections from an Instance, as well as sets the attached volumes to delete on termination. There is an option to create an AMI before termination, as a backup.

## Example

Will delete the AMI ami-12312132312 from the 222072124615 account. First it deregisters the AMI, then deletes the related snapshot(s) of that AMI. 

## Options

	[ --help|-h ] [ --instance-id|-i ] [ --profile|-p ] [ --snapshot|-s ] [ --force|-f]

	--help|-h		Print this help menu

	--instance-id|-i	Instance ID of the ami to be deleted

	--profile|-p		Provide the profile if logged in to multiple accounts simultaneously

	--backup|-b		Take backup AMI of instance before terminating

	--force|-f		Answer yes, useful for scripted terminations. Will create AMI automatically unless --no-backup is passed
