#!/usr/bin/env bash
set -e
##########################################################################
export CA_LOCATION=/etc/kubernetes/pki # Location of kubernetes ca.crt
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
##########################################################################
##########################################################################
    # Require sudo to run script
if [[ $UID != 0 ]]; then
    printf "\nPlease run this script with sudo: \n";
    printf "\n${RED} sudo $0 $* ${NC}\n\n";
    exit 1
fi
##########################################################################
#
# Generate a user private key
openssl genrsa -out metric-server.key 2048
wait $!
#
# Generate a CSR
openssl req -new -key metric-server.key -out metric-server.csr -subj "/CN=metric-server/O=poweruser/SAN=metrics-server.kube-system.svc"
wait $!
#
# On a k8s master, sign the CSR
openssl x509 -req -in metric-server.csr -CA ${CA_LOCATION}/ca.crt -CAkey ${CA_LOCATION}/ca.key -CAcreateserial -out metric-server.crt -days 500
wait $!
#
# Create a CertificateSigningRequest and submit it to a Kubernetes Cluster via kubectl
# request: is the base64 encoded value of the CSR file content. 
# You can get the content using this command: cat metric-server.csr | base64 | tr -d "\n"
#
ENCODED_REQUEST=$(cat metric-server.csr | base64 | tr -d "\n")
#
kubectl apply -f - <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: metric-server
spec:
  groups:
  - system:nodes
  - system:authenticated
  request: ${ENCODED_REQUEST}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF
wait $!
#
kubectl certificate approve metric-server
#
kubectl get csr/metric-server -o yaml
#
kubectl config set-credentials metric-server \
--client-key=/home/dalexander/k8s/kubernetes/certs/metric-server.key \
--client-certificate=/home/dalexander/k8s/kubernetes/certs/metric-server.crt \
--embed-certs=true
wait $!
set -e