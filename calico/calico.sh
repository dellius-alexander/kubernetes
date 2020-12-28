#!/usr/bin/env bash
###############################################################################
###############################################################################
###############################################################################
    # Verify kubelet present on host
KUBEADM=$(whereis kubeadm | gawk -c '{print $2}')
KUBECTL=$(whereis kubectl | gawk -c '{print $2}')
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
###############################################################################
###############################################################################
###############################################################################
    # Require sudo to run script
if [[ $UID != 0 ]]; then
    printf "\nPlease run this script with sudo: \n";
    printf "\n${RED} sudo $0 $* ${NC}\n\n";
    exit 1
fi
###############################################################################
###############################################################################
###############################################################################
    # Install calicoctl 
function install_calicoctl()
{
    # calicoctl
    # To interact directly with the Calico datastore, use the calicoctl client tool.
    # Install
    # Download the calicoctl binary to a Linux host with access to Kubernetes.
curl https://github.com/projectcalico/calicoctl/releases/download/v3.14.0/calicoctl -o calicoctl
wait $!
chmod +x calicoctl
mv calicoctl /usr/local/bin/
exit 0
    # Configure calicoctl to access Kubernetes.
    # On most systems, kubeconfig is located at ~/.kube/config. You may wish to add the 
    # export lines to your ~/.bashrc so they will persist when you log in next time.
}
###############################################################################
###############################################################################
###############################################################################
    ###############################################################################
    #   Create cni authentication
function create_cni_auth()
{
    # On the Kubernetes master node, create a key for the CNI plugin to authenticate 
    # with and certificate signing request.
openssl req -newkey rsa:4096 \
           -keyout cni.key \
           -nodes \
           -out cni.csr \
           -subj "/CN=calico-node"
    # We will sign this certificate using the main Kubernetes CA.
openssl x509 -req -in cni.csr \
                  -CA /etc/kubernetes/pki/ca.crt \
                  -CAkey /etc/kubernetes/pki/ca.key \
                  -CAcreateserial \
                  -out cni.crt \
                  -days 365

chown ${USER}:${USER} cni.crt
exit 0
}
###############################################################################
###############################################################################
###############################################################################
    ###############################################################################
    #   Create kubeconfig for cni plugin 
function create_cni_plugin()
{
    # Next, we create a kubeconfig file for the CNI plugin to use to access Kubernetes.
APISERVER=$(${KUBECTL} config view -o jsonpath='{.clusters[0].cluster.server}')

${KUBECTL}  config set-cluster kubernetes \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --server=${APISERVER} \
    --kubeconfig=cni.kubeconfig

${KUBECTL}  config set-credentials calico-cni \
    --client-certificate=cni.crt \
    --client-key=cni.key \
    --embed-certs=true \
    --kubeconfig=cni.kubeconfig

${KUBECTL} config set-context default \
    --cluster=kubernetes \
    --user=calico-node \
    --kubeconfig=cni.kubeconfig

${KUBECTL} config use-context default --kubeconfig=cni.kubeconfig
}
###############################################################################
###############################################################################
###############################################################################
    ###############################################################################
    # Create the custom resource definitions in Kubernetes.
${KUBECTL} apply -f crds.yaml

    # heck if calicoctl exist 
if [ $(whereis calicoctl | grep -c "calicoctl") == 0 ]; then
    install_calicoctl
fi
    # Verify calicoctl can reach your datastore by running

calicoctl get nodes &&
calicoctl get ippools &&
calicoctl create -f pool1.yaml &&
calicoctl create -f pool2.yaml &&
calicoctl get ippools
exit
wait $!
    # Create cni authentication
create_cni_auth
    # Create cni plugin kubeconfig 
create_cni_plugin
    # Apply the calico.yaml file
${KUBECTL} create clusterrolebinding calico-node --clusterrole=calico-node --user=calico-node
${KUBECTL}apply -f calico.yaml
    # Create the config directory

mkdir -p /etc/cni/net.d/
    # Copy the kubeconfig from the previous section
cp -i cni.kubeconfig  /etc/cni/net.d/calico-kubeconfig
chmod 600 /etc/cni/net.d/calico-kubeconfig