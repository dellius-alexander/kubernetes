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
elif [[ -z ${1} ]] && [[ ${1} =~ [^a-zA-Z0-9_-] ]]; then
  printf "\n\n${RED}Usage: ${0} <name of certificate>${NC}\n\n"
fi
##########################################################################
#
# Generate a user private key
openssl genrsa -out ${1}.key 2048
wait $!
#
# Generate a CSR
openssl req -new -key ${1}.key -out ${1}.csr -subj "/CN=${1}/SAN=${1}.kube-system.svc"
wait $!
#
# On a k8s master, sign the CSR
openssl x509 -req -in ${1}.csr -CA ${CA_LOCATION}/ca.crt -CAkey ${CA_LOCATION}/ca.key -CAcreateserial -out ${1}.crt -days 500
wait $!
#
# Create a CertificateSigningRequest and submit it to a Kubernetes Cluster via kubectl
# request: is the base64 encoded value of the CSR file content.
# You can get the content using this command: cat metric-server.csr | base64 | tr -d "\n"
#
__ENCODED_REQUEST__=$(cat ${1}.csr | base64 | tr -d "\n")
#
#printf "\n${__ENCODED_REQUEST__}\n"
#
cat <<EOF | kubectl apply -f -
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
#
kubectl certificate approve ${1}
#
kubectl get csr/${1} -o yaml
#
kubectl config set-credentials ${1} \
--client-key=/home/dalexander/k8s/kubernetes/certs/${1}.key \
--client-certificate=/home/dalexander/k8s/kubernetes/certs/${1}.crt \
--embed-certs=true
wait $!
##########################################################################
set -e