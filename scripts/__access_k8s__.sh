#!/usr/bin/env bash
set -e
##########################################################################
export CA_LOCATION=/etc/kubernetes/pki # Location of kubernetes ca.crt
export __KUBECONFIG__=/etc/kubernetes/admin.conf
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
openssl genrsa -out ${1}.key 2048 &&
wait $! &&
#
# Generate a CSR
openssl req -new -key ${1}.key -out ${1}.csr -subj "/CN=${1}/SAN=${1}.kube-system.svc" &&
wait $!  &&
#
# On a k8s master, sign the CSR
openssl x509 -req -in ${1}.csr -CA ${CA_LOCATION}/ca.crt -CAkey ${CA_LOCATION}/ca.key -CAcreateserial -out ${1}.crt -days 500 &&
wait $! &&
mkdir -p certs &&
mv ${1}.* certs/
#
# Create a CertificateSigningRequest and submit it to a Kubernetes Cluster via kubectl
# request: is the base64 encoded value of the CSR file content.
# You can get the content using this command: cat metric-server.csr | base64 | tr -d "\n"
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
#
kubectl certificate --kubeconfig=${__KUBECONFIG__} approve ${1}
#
kubectl get --kubeconfig=${__KUBECONFIG__} csr/${1} -o yaml
#
kubectl config --kubeconfig=${__KUBECONFIG__} set-credentials ${1} \
--client-key=$(find ~+ -type f -name "${1}.key") \
--client-certificate=$(find ~+ -type f -name "${1}.crt") \
--embed-certs=true
wait $!
##########################################################################
set -e