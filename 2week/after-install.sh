
export CLUSTER_NAME=myeks

# AWS Account 정보 확인 및 변수 지정
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo $ACCOUNT_ID

# myeks-VPC/Subnet 정보 확인 및 변수 지정
export VPCID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$CLUSTER_NAME-VPC" --query 'Vpcs[*].VpcId' --output text)
echo $VPCID

export PubSubnet1=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PublicSubnet1" --query "Subnets[0].[SubnetId]" --output text)
export PubSubnet2=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PublicSubnet2" --query "Subnets[0].[SubnetId]" --output text)
export PubSubnet3=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PublicSubnet3" --query "Subnets[0].[SubnetId]" --output text)
echo $PubSubnet1 $PubSubnet2 $PubSubnet3

export PrivateSubnet1=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PrivateSubnet1" --query "Subnets[0].[SubnetId]" --output text)
export PrivateSubnet2=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PrivateSubnet2" --query "Subnets[0].[SubnetId]" --output text)
export PrivateSubnet3=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PrivateSubnet3" --query "Subnets[0].[SubnetId]" --output text)
echo $PrivateSubnet1 $PrivateSubnet2 $PrivateSubnet3

# ssh 퍼블릭 키 경로 지정
SshPublic=~/.ssh/pki/pub.pub
echo $SshPublic

# 출력된 내용 참고 : 아래 yaml 파일 참고해서 vpc/subnet id, ssh key 경로 수정
eksctl create cluster --name $CLUSTER_NAME --region=ap-northeast-2 --nodegroup-name=ng1 --node-type=t3.medium --nodes 3 --node-volume-size=30 --vpc-public-subnets "$PubSubnet1","$PubSubnet2","$PubSubnet3" --version 1.31 --with-oidc --external-dns-access --full-ecr-access --alb-ingress-access --node-ami-family AmazonLinux2023 --ssh-access --dry-run > myeks.yaml
eksctl create cluster --name $CLUSTER_NAME --region=ap-northeast-2 --nodegroup-name=ng1 --node-type=t3.medium --nodes 3 --node-volume-size=30 --vpc-public-subnets "$PubSubnet1","$PubSubnet2","$PubSubnet3" --version 1.31 --with-oidc --external-dns-access --full-ecr-access --alb-ingress-access --node-ami-family AmazonLinux2023 --ssh-access --ssh-public-key $SshPublic --dry-run > myeks.yaml

export KUBECONFIG=$HOME/kubeconfig
혹은 각자 편한 경로 위치에 파일 지정
export KUBECONFIG=~/Downloads/kubeconfig

# 배포
eksctl create cluster -f myeks.yaml --verbose 4
