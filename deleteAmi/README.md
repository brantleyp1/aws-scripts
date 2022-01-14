# deleteAmi.sh

## Purpose

Quickly "delete" an AMI. Specifically, deregister an AMI and delete the related snapshot(s). This action is not recoverable, so be sure if you want to delete the AMI.

## Synopsis

To "delete" an AMI, first you have to deregister it. This won't affect currently running instances based on that AMI. Next you need to delete the snapshot(s) associated with the AMI. 

You can only deregister an AMI from the owning account.

Once the snapshots are removed and the AMI is deregistered, it can no longer be used to launch instances, is no longer shared to other accounts and will no longer incur AWS fees.

## Example

`deleteAmi.sh ami-12344555332`

Will delete the AMI ami-12344555332 from your currently logged in account. 

`deleteAmi.sh -a ami-12312132312 --profile 222072124615-ADFS-LIVE-ITOperations`

Will delete the AMI ami-12312132312 from the 222072124615 account. First it deregisters the AMI, then deletes the related snapshot(s) of that AMI. 

## Options

        [ --help|-h ] [ --ami-id|-a ] [ --profile|-p ]

        --help|-h       Print this help menu

        --ami-id|-a     AMI ID of the ami to be deleted

        --profile|-p    Provide the profile if logged in to multiple accounts simultaneously
