# yaml 파일 다운로드
curl -O https://s3.ap-northeast-2.amazonaws.com/cloudformation.cloudneta.net/K8S/myeks-2week.yaml

aws cloudformation deploy --template-file myeks-2week.yaml --stack-name myeks --parameter-overrides KeyName=pub SgIngressSshCidr=$(curl -s ipinfo.io/ip)/32 --region ap-northeast-2

# CloudFormation 스택 배포 완료 후 운영서버 EC2 IP 출력
aws cloudformation describe-stacks --stack-name myeks --query 'Stacks[*].Outputs[*].OutputValue' --output text

# 운영서버 EC2 에 SSH 접속
ssh -i ~/.ssh/pki/pub.pem ec2-user@$(aws cloudformation describe-stacks --stack-name myeks --query 'Stacks[*].Outputs[0].OutputValue' --output text)
