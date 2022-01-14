# migrateInstance.sh

## Purpose

Migrate script to move a running instance from one account to another account. Can be used to move an instance to a new AZ as well.

## Synopsis

This script can also be used for copying existing AMIs or instances that have encypted snapshot/volumes. It will create a new key in the source account named alias/legacyMigration to re-encrypt the AMI so it can be launched in the destination account. 

There is an option to clean up the AMI(s) and migration key. The AMI(s) are deleted immediately and are not recoverable. The key is "scheduled" for deletion with a window of 14 days. If this script is run again before that window is elapsed it removes the deletion schedule and re-enables the key to allow instances launched in the destination account. The option to clean the AMI(s) and key can still be applied.

## Examples

`./migrateInstance.sh -i i-0b4c6a0c4bdf8df83 -p 222072124615-ADFS-LIVE-ITOperations -g`

This will copy the existing tags for the instance i-0b4c6a0c4bdf8df83 found in account 222072124615. After it copies the tags it opens them in VI to edit as appropriate. It lists the tags for the running instance and any volumes attached, you have to verify if the required tags are present and correct, but then the script will pull the correct values from the list for the new instance and any volumes that will be attached at launch.

`./migrateInstance.sh -i i-0b4c6a0c4bdf8df83 -d 968838427678-ADFS-WORK-ITOperationsAdvanced -p 222072124615-ADFS-LIVE-ITOperations -s private -S management`

Will take an instance running in account 222072124615, take an AMI of it, share that AMI to account 968838427678, then start the instance based on the tags previously supplied. It will put the instance in the private subnet and the management security group.

`./migrateInstance.sh -i i-03dae4bef965aed67 -d 968838427678-ADFS-WORK-ITOperationsAdvanced -p 222072124615-ADFS-LIVE-ITOperations -s private -S management -t tags.migrate -E ami-081c53b8a587d0d1c`

Will take an existing AMI, skip past the stage to create and AMI and the stage to copy an encrypted AMI and jump to sharing and launching an instance based on that image. Used to save the create-image step, for times where the image is created but the script was not able to run to completion.

## Options

[--help|-h] [--generate|-g] [--instance|-i] [--destination|-d] [--profile|-p] [--clean|-c] [--subnet|-s] [--security-group|-S] [--az|-a] [--tags|-t] [--encrypted-ami|-E] [--reboot|-r] [--turn-off|-o] [--terminate|-O]

-h | --help - This menu

-g | --generate - Build initial file containing tags of existing instance, it will open in vi to edit

-i | --instance - Required - source instance to be migrated

-d | --destination - Required(unless just running tags) - the Destination profile/account you want to build instance in

-p | --profile - Required - the Target profile/account you want to copy instances from

-s | --subnet - Private subnet is default. Choices are: private, public, subnet-XXX for a specific subnet

-S | --security-group - Security Group selection. Choices are: private, public, management, applicataion, storage

-a | --az - Set Availability zone if different than us-east-1a

-t | --tags - File/path to file with required tags and values, in csv format, using `=` to differentiate between the Key and the Value

-c | --clean - Delete AMIs created through this process and schedule key for deletion

-I | --ami-id - Provide the AMI to skip process of building new AMI on instance

-E | --encrypted-ami - Provide the AMI to skip process of copying the new AMI on instance

-r | --reboot - Allow create-image to reboot instance, much faster but will cause interruption

-o | --turn-off - Stop instance after migration process

-O | --terminate - Terminate instance after migration process

-w | --windows - Disables user-data settings (for now, could be used to set powershell in the future)


## Notes

As of version 2, this will also work if the volumes of the running instance are encrypted.

Still no powershell option

