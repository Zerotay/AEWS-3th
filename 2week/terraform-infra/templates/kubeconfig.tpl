apiVersion: v1
preferences: {}
kind: Config
clusters:
- cluster:
    server: ${endpoint}
    certificate-authority-data: ${cluster_auth_base64}
  name: ${endpoint}

contexts:
- context:
    cluster: ${endpoint}
    user: ${user_arn}
  name: ${cluster_name}

current-context: ${cluster_name}

users:
- name: ${user_arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - --region
      - ${region}
      - eks
      - get-token
      - --cluster-name
      - ${cluster_name}
      - --output
      - json
      command: aws
      env: null
      interactiveMode: IfAvailable
      provideClusterInfo: false
