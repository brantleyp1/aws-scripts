#! /bin/bash
#
# loadBalancer.sh
#
################################
#
# Trying to build a load balancer. 
# gonna try to make it work then add in 
# options as they pop up.
# 
################################
# 



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
bbvaopsinstancescheduler=$(grep -E "\<instancescheduler\>" ${temptagfile} | grep -vE "^#" | awk -F'=' '{ print $2 }')

TAGtext="\
Key=bbva-ops-uuaa,Value=$bbvaopsuuaa, \
Key=bbva-ops-operationalband,Value=$bbvaopsoperationalband, \
Key=bbva-ops-logicalenvironment,Value=$bbvaopslogicalenvironment, \
Key=bbva-arch-projectname,Value=$bbvaarchprojectname, \
Key=bbva-arch-workload,Value=$bbvaarchworkload, \
Key=bbva-ops-lineofbusiness,Value=$bbvaopslineofbusiness, \
Key=bbva-ops-lineofbusinesslevel2,Value=$bbvaopslineofbusinesslevel2, \
Key=bbva-arch-initiative,Value=$bbvaarchinitiative, \
Key=bbva-ops-techcontact,Value=$bbvaopstechcontact, \
Key=bbva-ops-createdby,Value=$bbvaopscreatedby, \
Key=bbva-isg-pci,Value=$bbvaisgpci, \
Key=bbva-isg-pii,Value=$bbvaisgpii, \
Key=bbva-isg-sox,Value=$bbvaisgsox, \
Key=bbva-arch-appcmdb,Value=$bbvaarchappcmdb, \
Key=bbva-ops-instancescheduler,Value=$bbvaopsinstancescheduler\
"
fi
} # end of tagfun function

# create LB
#need to find subnetids
${awscommand} elbv2 create-load-balancer --name ${lbName} --type ${lbType} --subnets ${subnetID} --tags ${TAGtext} --query 'LoadBalancers[].LoadBalancerArn' --output text

# create target group for lb
# Setting VPCID and allowing for multiples or if not found
#needs to be separate function
VPCID=$(${awscommand} ec2 describe-vpcs --filter Name=tag:Name,Values=[$ACCT*] --output text --query 'Vpcs[].VpcId')
if [ $(echo "$VPCID" | wc | awk '{ print $2 }') -ne 1 ]; then
        vpcarray=($(${awscommand} ec2 describe-vpcs --query 'Vpcs[].[VpcId,Tags[?Key==`Name`].Value]' --filter Name=tag:Name,Values=[*] | tr -d '\n' | sed -e 's/[] ,[]//g' | sed -e 's/"/ /g'))
        count=0
        arrlength=${#vpcarray[@]}
        if [[ "$arrlength" -eq 2 ]]; then
                VPCID=${vpcarray[0]}
        elif [[ "$arrlength" -gt 2 ]]; then
        echo -e "\nI couldn't find a VPC with a name of $ACCT, but I found some others. Your otions are:"
        for (( index=1; index<${#vpcarray[@]}; index+=2 ))
        do
                echo "$((count+=1)) - ${vpcarray[$index]}"
        done
        echo "Select which VPC name to continue..."
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
                * ) echo -e "\nThere are too many VPCs, please run \"aws ec2 describe-vpcs --query 'Vpcs[*][Tags[?Key==\`Name\`] | [0].Value, VpcId, CidrBlock]' --output table\""; exit ;;
        esac

        choice2=$(($choice - 1 ))
        echo -e "\nContinuing with ${vpcarray[$choice]}"
        sleep 1
        VPCID=${vpcarray[$choice2]}
        else
                echo -e "\nNot sure this account was built correctly, you need to run this command manually to see if there are any named VPCs:\n\"aws ec2 describe-vpcs --query 'Vpcs[*][Tags[?Key==\`Name\`] | [0].Value, VpcId, CidrBlock]' --output table\""
                exit
        fi

fi

${awscommand} elbv2 create-target-group --name ${targName} --protocol ${protocol} --port ${port} --vpc-id ${vpcID} --query 'TargetGroups[].TargetGroupArn' --output text

# register targets
#register arn from create target group as targGrpArn
#array to list instances to be targets
${awscommand} elbv2 register-targets --target-group-arn ${targGrpArn} --targets Id=i-12345678 Id=i-23456789

# create listeners
#register arn from create-load-balancer as loadBalArn
#while loop for each protocol/port combination
#there are A LOT of options for this, going with most basic
${awscommand} elbv2 create-listener --load-balancer-arn ${loadBalArn} --protocol ${protocol} --port ${port} --default-actions Type=forward,TargetGroupArn=${targGrpArn}

# check target health
#not needed, may discard
${awscommand} elbv2 describe-target-health --target-group-arn ${targGrpArn}

# specify EIP for LB
#to use, will have to know upfront the subnetid and eip ids
${awscommand} elbv2 create-load-balancer --name my-load-balancer --type network --subnet-mappings SubnetId=subnet-12345678,AllocationId=eipalloc-12345678

# help functions
helptext="\
Usage $0
	--help|-h	Print this help menu
	--test|-H	Run script without making changes or stopping instances
	--instance|-i	Specify Instance ID. If not supplied script will prompt for ID
	--type|-t	Specify target size for instance
	--force|-y	Accept all prompts as yes
	--feed|-f	Present csv file of multiple Instance IDs and target sizes
	--profile|-p	Provide the profile if logged in to multiple accounts simultaneously
	--snapshot|-s	Take snapshots of all attached volumes before resizing
"
helptext2="\
Usage $0
	[ --help|-h ] [ --test|-H ] [ --instance|-i ] [ --type|-t ] [ --force|-y ] [ --feed|-f ] [ --profile|-p ] [ --snapshot|-s ]"
usage () {
echo "$helptext"
exit
}
errusage () {
echo "$helptext2"
exit
}

##  Transform long options to short ones
for arg in "$@"; do
  shift
  case "$arg" in
    "--help") set -- "$@" "-h" ;;
    "--test") set -- "$@" "-H" ;;
    "--instance") set -- "$@" "-i" ;;
    "--force") set -- "$@" "-y" ;;
    "--snapshot") set -- "$@" "-s" ;;
    "--feed") set -- "$@" "-f" ;;
    "--profile") set -- "$@" "-p" ;;
    "--type") set -- "$@" "-t" ;;
    *)        set -- "$@" "$arg"
  esac
done

##  Parse short options
OPTIND=1
while getopts "hHi:ysf:p:t:" opt
do
  case "${opt}" in
    h)  usage
        ;;
    H)  TEST=true
        ;;
    i)  InsID=$OPTARG
        ;;
    y)  FORCE=true
        ;;
    s)  SnapShot=true
        ;;
    f)  FileFeed=$OPTARG
	FORCE=true
        ;;
    t)  targetSize=$OPTARG
        ;;
    p)  runprofile=$OPTARG
        ;;
    ?)  errusage >&2
        ;;
  esac
done
shift $(expr $OPTIND - 1) # remove options from positional parameters

if [ -n "$runprofile" ]; then
	awscommand="aws --profile"
else
	awscommand="aws"
fi

