# runInstance.sh

## Purpose

Launch instances pretty quickly, either a single instance by passing tags via a tag file or multiple instances using a csv file.

## Example

`./runInstance.sh -f list.csv`

Will pull all required data from list.csv and feed it to the script, launching as many instances as are listed, from one to several.

`./runInstance.sh -i rhel-7-golden -A 303068756901 -b live -P 10.240.168.201 -S management -v 500 -t tags -I i3.2xlarge`

Will build a single instance based on the "rhel-7-golden" image. It will pull the image from the 303068756901 account (ITSM-Live). The Band will be live, used for naming the key correctly. It will automatically launch with an IP assigned, usefull for rebuilding/replacing a running instance with firewall rules. It will be in the management security group and will use the tags found in a file name "tags". 

## Options

> Not all options are required. Unless specified: `--image` will default to the "rhel-7-golden" image; `--subnet` will assume private unless called, if called will assume public; `--volume-size` will assume 50G for the root volume; `--instance-type` will assume t2.micro unless specified; `--profile` will run as whatever profile is currently logged in and set as environment variable $AWS_PROFILE or found in ~/.aws/credentials.

> Also, note, if not passing `--account-number`, then you will need to pass `--account` and `--band`, as they are used to find the account number from ~/.aws/credentials. `--band` is required to name the key correctly though.

> `--tags` is required if running for a single instance, otherwise `--feed` csv file will provide the required tags. 


`--help | -h`	- This menu

`--test | -H`	- Build command without launching instances

`--image | -i`	- What image to base the new instance on, rhel or cent

`--account | -a`	- Which account, i.e. igel

`--account-number | -A`	- Specify the account by number

`--band | -b`	- Which band to run this in, required when using --account flag

`--subnet | -s`	- Public or Private subnet. Default is private, flag will select public

`--security-group | -S`	- Security Group selection. Choices are: private, public, management, applicataion, storage

`--volume-size | -v`	- Size of EBS volume

`--instance-type | -I`	- Instance type, i.e. t2.large

`--profile | -p`	- Pass AWS profile if you're signed in to multiple accounts simultaneously

`--ip-address | -P`	- Feed specific IP. Must be in CIDR range of subnet selected. Usefull if rebuilding existing instance with firewall rules

`--tags | -t`	- File/path to file with required tags and values, in csv format

`--feed | -f`	- Feed a csv file with names, tags, and pertinent info at one time. This supercedes the other options

