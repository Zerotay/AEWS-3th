# kubestr
wget https://github.com/kastenhq/kubestr/releases/download/v0.4.48/kubestr_0.4.48_Linux_amd64.tar.gz
tar xvfz kubestr_0.4.48_Linux_amd64.tar.gz && mv kubestr /usr/local/bin/ && chmod +x /usr/local/bin/kubestr
# local-path-provisioner
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.31/deploy/local-path-storage.yaml
