# shareImage.sh

## General

The share image will allow you to share the rhel image from Account: bbva-live-itservicemanagement (303068756901) to whatever target account you need.
This currently requires a key(KMS) edit as well to allow the target account to open the snapshot of the ami. This *currently* has to be done by the console.

Also this script checks if the image is already shared with the target account

You can use this script to search for rhel or cent, just know you'll have to be pretty specific.

## Specifics

Making quick changes to Readme, the script was overhauled to allow any of these to be passed at CLI.

The script starts with a couple of variables that need to be set. 

*  WhatImage=rhel

This is the image you're searching for. See the example below, rhel finds the latest rhel ami, cent brings back several results and the script isn't set up for multiples. You can search for "bbva-ea-centos-7-v1.5" to find the latest cent image.

> The command the script runs is:
```
aws ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageLocation, \`${WhatImage}\`) == \`true\`].[ImageId]" --output text
```

*  WhatTargetAcct=igel

This script is assuming you're using the stshelper script. It generates a list of the accounts available to you and finds the account number based on this list. It may be possible to set this to the specific account number and it'll still work, will have to investigate.

*  WhatBand=work

The band you're sharing to, `live`, `work`, or `play`. This is used to find the account number, it might go away in future releases.

## New Options

`-h|--help`               Print this help file

`-c|--test`               Test your settings before you commit

`-i|--image`              The image you want to search for, i.e. rhel

	>	If unsure, run this to see a list of BBVA-EA approved images:
	>	\"aws ec2 describe-images --owners 303068756901 --query 'Images[?contains(ImageLocation, \`bbva\`) == \`true\`].[Name]' --output text\"

`-b|--band`               Set the band, i.e. play. --band and --target must be used together

`-t|--target`             Set the destination account, i.e. igel

`-a|--account-number`     Set the destination account by number. If using this option, band and target are not required

`-s|--source`             Specify the source account if other than 303068756901. If not set script will look in IT Service Management Live account

### Example:

If you're searching for "cent", you get:
```
$ aws ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageLocation, \`cent\`) == \`true\`].[ImageId,Name]" --output text
ami-01d7c211abacde794   bbva-ea-centos-7-v1.3.0-1566232698
ami-01fec6cb763840bdc   bbva-ea-centos-7-v1.4.0-1568050210
ami-06de268179f709de3   bbva-ea-centos-7-v1.2.0
ami-097e9ab7830e4441e   bbva-ea-centos-7-v1.1.1
ami-0ad28de8c0c58b7b2   bbva-ea-centos-7-v1.5.0-1568672012
ami-0f6d16116d54b86ce   bbva-ea-centos-7-v1.0.0
```

But searching for "bbva-ea-centos-7-v1.5" gets:
```
$ aws ec2 describe-images --owners 303068756901 --query "Images[?contains(ImageLocation, \`bbva-ea-centos-7-v1.5\`) == \`true\`].[ImageId,Name]" --output text
ami-0ad28de8c0c58b7b2   bbva-ea-centos-7-v1.5.0-1568672012
```

That single line output can be used in the script. 


### Note

I need to rewrite this and will clean up docs asap
