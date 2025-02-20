
curl -O https://s3.ap-northeast-2.amazonaws.com/cloudformation.cloudneta.net/K8S/myeks-3week.yaml
# aws cloudformation deploy --template-file myeks-1week.yaml --stack-name mykops --parameter-overrides KeyName=<My SSH Keyname> SgIngressSshCidr=<My Home Public IP Address>/32 --region <리전>
aws cloudformation deploy --template-file ./myeks-3week.yaml \
     --stack-name myeks --parameter-overrides KeyName=pub SgIngressSshCidr=$(curl -s ipinfo.io/ip)/32 --region ap-northeast-2

aws cloudformation describe-stacks --stack-name myeks --query 'Stacks[*].Outputs[*].OutputValue' --output text

ssh  ec2-user@$(aws cloudformation describe-stacks --stack-name myeks --query 'Stacks[*].Outputs[0].OutputValue' --output text)
