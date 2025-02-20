kubectl cluster-info

# 네임스페이스 default 변경 적용
kubens default

# 
kubectl ctx
kubectl config rename-context "<각자 자신의 IAM User>@myeks.ap-northeast-2.eksctl.io" "eksworkshop"
kubectl config rename-context "admin@myeks.ap-northeast-2.eksctl.io" "eksworkshop"

#
kubectl get node --label-columns=node.kubernetes.io/instance-type,eks.amazonaws.com/capacityType,topology.kubernetes.io/zone
kubectl get node -v=6

#
kubectl get pod -A
kubectl get pdb -n kube-system

# 관리형 노드 그룹 확인
eksctl get nodegroup --cluster $CLUSTER_NAME
aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name ng1 | jq

# eks addon 확인
eksctl get addon --cluster $CLUSTER_NAME

# aws-load-balancer-controller를 위한 iam service account 생성 확인 : AWS IAM role bound to a Kubernetes service account
eksctl get iamserviceaccount --cluster $CLUSTER_NAME
NAMESPACE	NAME				ROLE ARN
kube-system	aws-load-balancer-controller	arn:aws:iam::911283464785:role/eksctl-myeks-addon-iamserviceaccount-kube-sys-Role1-S60JsHI62pHB

# 인스턴스 정보 확인 1
aws ec2 describe-instances --query "Reservations[*].Instances[*].{InstanceID:InstanceId, PublicIPAdd:PublicIpAddress, PrivateIPAdd:PrivateIpAddress, InstanceName:Tags[?Key=='Name']|[0].Value, Status:State.Name}" --filters Name=instance-state-name,Values=running --output table

# 인스턴스 정보 확인 2 : AZ, ID, 공인IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=myeks-ng1-Node" \
    --query "Reservations[].Instances[].{InstanceID:InstanceId, PublicIP:PublicIpAddress, AZ:Placement.AvailabilityZone}" \
    --output table

# AZ1 배치된 EC2 공인 IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=myeks-ng1-Node" "Name=availability-zone,Values=ap-northeast-2a" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text

# AZ2 배치된 EC2 공인 IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=myeks-ng1-Node" "Name=availability-zone,Values=ap-northeast-2b" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text

# AZ3 배치된 EC2 공인 IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=myeks-ng1-Node" "Name=availability-zone,Values=ap-northeast-2c" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text

# EC2 공인 IP 변수 지정
export N1=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=myeks-ng1-Node" "Name=availability-zone,Values=ap-northeast-2a" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
export N2=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=myeks-ng1-Node" "Name=availability-zone,Values=ap-northeast-2b" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
export N3=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=myeks-ng1-Node" "Name=availability-zone,Values=ap-northeast-2c" --query 'Reservations[*].Instances[*].PublicIpAddress' --output text)
echo $N1, $N2, $N3


# *remoteAccess* 포함된 보안그룹 ID
aws ec2 describe-security-groups --filters "Name=group-name,Values=*remoteAccess*" | jq
export MNSGID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=*remoteAccess*" --query 'SecurityGroups[*].GroupId' --output text)

# 해당 보안그룹 inbound 에 자신의 집 공인 IP 룰 추가
aws ec2 authorize-security-group-ingress --group-id $MNSGID --protocol '-1' --cidr $(curl -s ipinfo.io/ip)/32

# 해당 보안그룹 inbound 에 운영서버 내부 IP 룰 추가
aws ec2 authorize-security-group-ingress --group-id $MNSGID --protocol '-1' --cidr 172.20.1.100/32


# ping 테스트
ping -c 2 $N1
ping -c 2 $N2
ping -c 2 $N3

# 워커 노드 SSH 접속
ssh -i <SSH 키> -o StrictHostKeyChecking=no ec2-user@$N1 hostname
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh -o StrictHostKeyChecking=no ec2-user@$i hostname; echo; done

ssh ec2-user@$N1
exit
ssh ec2-user@$N2
exit
ssh ec2-user@$N2
exit

# 노드 기본 정보 확인
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh ec2-user@$i hostnamectl; echo; done
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh ec2-user@$i sudo ip -c addr; echo; done

# 
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh ec2-user@$i lsblk; echo; done
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh ec2-user@$i df -hT /; echo; done


# 스토리지클래스 및 CSI 노드 확인
kubectl get sc
kubectl describe sc gp2

kubectl get crd
kubectl get csinodes


# max-pods 정보 확인
kubectl describe node | grep Capacity: -A13
kubectl get nodes -o custom-columns="NAME:.metadata.name,MAXPODS:.status.capacity.pods"

# 노드에서 확인
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh ec2-user@$i cat /etc/eks/bootstrap.sh; echo; done
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh ec2-user@$i sudo cat /etc/kubernetes/kubelet/config.json | grep maxPods; echo; done
for i in $N1 $N2 $N3; do echo ">> node $i <<"; ssh ec2-user@$i sudo cat /etc/kubernetes/kubelet/config.json.d/00-nodeadm.conf | grep maxPods; echo; done
