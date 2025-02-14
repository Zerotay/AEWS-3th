#!/bin/zsh
read N1 N2 <<(kubectl get node -o jsonpath='{.items}' | jq -r '.[] | .status.addresses[] | select(.type == "ExternalIP").address' | paste -sd " ")
export N1 N2


# ssh -i ../pki/pub.pem ec2-user@$N1
