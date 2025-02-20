# eks 설치한 iam 자격증명을 설정하기
aws configure

# get-caller-identity 확인
aws sts get-caller-identity --query Arn

# kubeconfig 생성
aws eks update-kubeconfig --name myeks --user-alias <위 출력된 자격증명 사용자>
aws eks update-kubeconfig --name myeks --user-alias admin

# 
kubectl cluster-info
kubectl ns default
kubectl get node -v6



# 현재 EFS 정보 확인
aws efs describe-file-systems | jq

# 파일 시스템 ID만 출력
aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text
fs-040469b8fab273469

# EFS 마운트 대상 정보 확인
aws efs describe-mount-targets --file-system-id $(aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text) | jq

# IP만 출력 : 
aws efs describe-mount-targets --file-system-id $(aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text) --query "MountTargets[*].IpAddress" --output text
192.168.2.102	192.168.1.71	192.168.3.184

# DNS 질의 : 안되는 이유가 무엇일까요?
# EFS 도메인 이름(예시) : fs-040469b8fab273469.efs.ap-northeast-2.amazonaws.com
dig +short $(aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text).efs.ap-northeast-2.amazonaws.com


# EFS 마운트 테스트
EFSIP1=<IP만 출력에서 아무 IP나 지정>
EFSIP1=192.168.1.71

df -hT
mkdir /mnt/myefs
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport $EFSIP1:/ /mnt/myefs
findmnt -t nfs4
df -hT --type nfs4

# 파일 작성
nfsstat
echo "EKS Workshop" > /mnt/myefs/memo.txt
nfsstat
ls -l /mnt/myefs
cat /mnt/myefs/memo.txt

# EC2 재부팅 이후에도 mount 탑재가 될 수 있게 설정 해보자! : (힌트 : /etc/fstab)
