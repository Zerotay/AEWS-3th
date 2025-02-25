#!/bin/bash
hostnamectl --static set-hostname "operator-host"

# Config convenience
echo 'alias vi=vim' >> /etc/profile
echo "sudo su -" >> /home/ec2-user/.bashrc
sed -i "s/UTC/Asia\/Seoul/g" /etc/sysconfig/clock
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# Install Packages
yum -y install tree jq git htop unzip bind-utils vim

# Install kubectl & helm
cd /root
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.2/2024-11-15/bin/linux/amd64/kubectl
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Install eksctl
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin

# Install aws cli v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip >/dev/null 2>&1
./aws/install
echo "complete -C '/usr/local/bin/aws_completer' aws" >>/etc/profile
echo 'export AWS_PAGER=""' >>/etc/profile 

# Install krew
curl -L https://github.com/kubernetes-sigs/krew/releases/download/v0.4.4/krew-linux_amd64.tar.gz -o /root/krew-linux_amd64.tar.gz
tar zxvf krew-linux_amd64.tar.gz
./krew-linux_amd64 install krew
export PATH="$PATH:/root/.krew/bin"
echo 'export PATH="$PATH:/root/.krew/bin"' >> /etc/profile

# Install kube-ps1
kubectl completion bash >> /etc/profile
echo 'alias k=kubectl' >> /etc/profile
echo 'complete -F __start_kubectl k' >> /etc/profile

git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1
cat <<"EOT" >> /root/.bash_profile
source /root/kube-ps1/kube-ps1.sh
KUBE_PS1_SYMBOL_ENABLE=false
function get_cluster_short() {
  echo "$1" | cut -d . -f1
}
KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
KUBE_PS1_SUFFIX=') '
PS1='$(kube_ps1)'$PS1
EOT

# Install krew plugin
kubectl krew install ctx ns get-all neat # ktop df-pv mtail tree

# Install Docker
amazon-linux-extras install docker -y
systemctl start docker && systemctl enable docker

# Install Kubecolor
wget https://github.com/kubecolor/kubecolor/releases/download/v0.5.0/kubecolor_0.5.0_linux_amd64.tar.gz
tar -zxvf kubecolor_0.5.0_linux_amd64.tar.gz
mv kubecolor /usr/local/bin/

# network settings

mkdir -p ~/.aws
echo "${aws_credentials}" > ~/.aws/credentials
echo "${aws_config}" > ~/.aws/config
echo "${ssh_key}" > ~/eks-key.pem
chmod 0400 ~/eks-key.pem

export CLUSTER_NAME=${cluster_name}
echo 'export CLUSTER_NAME=${cluster_name}' >> /etc/profile
export VPCID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$CLUSTER_NAME-VPC" --query  'Vpcs[*].VpcId' --output text)
echo "export VPCID=$VPCID" >> /etc/profile
export PubSubnet1=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-PublicSubnet0" --query "Subnets[0].[SubnetId]" --output text)
echo "export PubSubnet1=$PubSubnet1" >> /etc/profile
export PubSubnet2=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-PublicSubnet1" --query "Subnets[0].[SubnetId]" --output text)
echo "export PubSubnet2=$PubSubnet2" >> /etc/profile
export PubSubnet3=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-PublicSubnet2" --query "Subnets[0].[SubnetId]" --output text)
echo "export PubSubnet3=$PubSubnet3" >> /etc/profile

AZ1="ap-northeast-2a"
AZ2="ap-northeast-2b"
AZ3="ap-northeast-2c"
echo "export N1=$(aws ec2 describe-instances   --filters "Name=subnet-id,Values=$PubSubnet1" "Name=instance-state-name,Values=running"   --query "Reservations[0].Instances[0].PrivateIpAddress"   --output text)" >> /etc/profile
echo "export N2=$(aws ec2 describe-instances   --filters "Name=subnet-id,Values=$PubSubnet2" "Name=instance-state-name,Values=running"   --query "Reservations[0].Instances[0].PrivateIpAddress"   --output text)" >> /etc/profile
echo "export N3=$(aws ec2 describe-instances   --filters "Name=subnet-id,Values=$PubSubnet3" "Name=instance-state-name,Values=running"   --query "Reservations[0].Instances[0].PrivateIpAddress"   --output text)" >> /etc/profile
 
mkdir -p ~/.kube
echo "${kubeconfig}" > ~/.kube/config

#vim setting
cat <<EOF >> ~/.vimrc
set nu
set ai 
set si
set ts=2
set sts=2
set et
set sw=2
syntax on
EOF

mkdir -p ~/.ssh
cat <<EOF >> ~/.ssh/config
Host *
    User ec2-user
    Port 22
    IdentityFile ~/eks-key.pem
EOF

rm  -f *.zip *.gz
