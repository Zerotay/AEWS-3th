export CLUSTER_NAME=myeks

# myeks-VPC/Subnet 정보 확인 및 변수 지정
export VPCID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=$CLUSTER_NAME-VPC" --query 'Vpcs[*].VpcId' --output text)
echo $VPCID

export PubSubnet1=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PublicSubnet1" --query "Subnets[0].[SubnetId]" --output text)
export PubSubnet2=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PublicSubnet2" --query "Subnets[0].[SubnetId]" --output text)
export PubSubnet3=$(aws ec2 describe-subnets --filters Name=tag:Name,Values="$CLUSTER_NAME-Vpc1PublicSubnet3" --query "Subnets[0].[SubnetId]" --output text)
echo $PubSubnet1 $PubSubnet2 $PubSubnet3

SSHKEYNAME=pub

cat << EOF > myeks.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: myeks
  region: ap-northeast-2
  version: "1.31"

iam:
  withOIDC: true # enables the IAM OIDC provider as well as IRSA for the Amazon CNI plugin

  serviceAccounts: # service accounts to create in the cluster. See IAM Service Accounts
  - metadata:
      name: aws-load-balancer-controller
      namespace: kube-system
    wellKnownPolicies:
      awsLoadBalancerController: true

vpc:
  cidr: 192.168.0.0/16
  clusterEndpoints:
    privateAccess: true # if you only want to allow private access to the cluster
    publicAccess: true # if you want to allow public access to the cluster
  id: $VPCID
  subnets:
    public:
      ap-northeast-2a:
        az: ap-northeast-2a
        cidr: 192.168.1.0/24
        id: $PubSubnet1
      ap-northeast-2b:
        az: ap-northeast-2b
        cidr: 192.168.2.0/24
        id: $PubSubnet2
      ap-northeast-2c:
        az: ap-northeast-2c
        cidr: 192.168.3.0/24
        id: $PubSubnet3

addons:
  - name: vpc-cni # no version is specified so it deploys the default version
    version: latest # auto discovers the latest available
    attachPolicyARNs: # attach IAM policies to the add-on's service account
      - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    configurationValues: |-
      enableNetworkPolicy: "true"

  - name: kube-proxy
    version: latest

  - name: coredns
    version: latest

  - name: metrics-server
    version: latest

managedNodeGroups:
- amiFamily: AmazonLinux2023
  desiredCapacity: 3
  iam:
    withAddonPolicies:
      certManager: true # Enable cert-manager
      externalDNS: true # Enable ExternalDNS
  instanceType: t3.medium
  preBootstrapCommands:
    # install additional packages
    - "dnf install nvme-cli links tree tcpdump sysstat ipvsadm ipset bind-utils htop -y"
  labels:
    alpha.eksctl.io/cluster-name: myeks
    alpha.eksctl.io/nodegroup-name: ng1
  maxPodsPerNode: 100
  maxSize: 3
  minSize: 3
  name: ng1
  ssh:
    allow: true
    publicKeyName: $SSHKEYNAME
  tags:
    alpha.eksctl.io/nodegroup-name: ng1
    alpha.eksctl.io/nodegroup-type: managed
  volumeIOPS: 3000
  volumeSize: 120
  volumeThroughput: 125
  volumeType: gp3
EOF



eksctl create cluster -f myeks.yaml --verbose 4
