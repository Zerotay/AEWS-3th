export VPCID=$(aws ec2 describe-vpcs | jq  -r '.Vpcs[] | select(has("Tags") and .Tags[].Value == "myeks-VPC").VpcId')
export PubSubnet1=$( aws ec2 describe-subnets | jq -r '.Subnets[] | select(.VpcId == env.VPCID) | select(.Tags[].Value == "myeks-PublicSubnet1").SubnetId')
export PubSubnet2=$( aws ec2 describe-subnets | jq -r '.Subnets[] | select(.VpcId == env.VPCID) | select(.Tags[].Value == "myeks-PublicSubnet2").SubnetId')

