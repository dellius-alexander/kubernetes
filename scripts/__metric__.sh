#!/usr/bin/env bash
################################################################
__KUBECTL__=$(command -v kubectl)
################################################################
# 1. Create a Certificate Signing Request
cat <<EOF | cfssl genkey - | cfssljson -bare kubelet-server
{
  "hosts": [
    "k8s-master",
    "k8s-worker-1",
    "k8s-worker-2",
    "k8s-worker-3",
    "10.0.0.40",
    "10.0.0.41",
    "10.0.0.42",
    "10.0.0.43"
  ],
  "CN": "kubelet-server",
  "key": {
    "algo": "ecdsa",
    "size": 256
  }
}
EOF
################################################################
# Create a CertificateSigningRequest and submit it to a Kubernetes Cluster via kubectl
# request: is the base64 encoded value of the CSR file content.
# You can get the content using this command: cat metrics-server.csr | base64 | tr -d "\n"
#
__ENCODED_REQUEST__=$(cat certs/${1}.csr | base64 | tr -d "\n")
#
#printf "\n${__ENCODED_REQUEST__}\n"
#
cat <<EOF | kubectl apply --kubeconfig=${__KUBECONFIG__} -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${1}
spec:
  groups:
  - system:nodes
  - system:authenticated
  request: ${__ENCODED_REQUEST__}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
wait $!
################################################################
# Deploy the Metric Server
#
${__KUBECTL__} create -f metrics-server.yaml