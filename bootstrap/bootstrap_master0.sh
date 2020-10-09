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
#               VERIFY KUBEADM AND KUBECTL BINARIES
###############################################################################
function kube_binary(){
    # Require sudo to run script
if [[ -z ${KUBEADM} ]]; then
    printf "\nUnable to locate ${RED}kubeadm${NC} binary. \nPlease re-run this script using the ${RED}--setup${NC} flag.\n Usage:${RED} $0 [ --reset | --setup ]${NC}\n";
    printf "\n${RED}sudo $0 $*${NC}";
    exit 1
elif [[ -z ${KUBECTL} ]]; then
        printf "\nUnable to locate ${RED}kubelet${NC} binary. \nPlease re-run this script using the ${RED}--setup${NC} flag.\n Usage:${RED} $0 [ --reset | --setup ]${NC}\n";
    printf "\n$RED}sudo $0 $*${NC}";
    exit 1
fi
}

###############################################################################
###############################################################################
#               SETUP FIREWALL RULES
###############################################################################
function firewall_rules(){
###############################################################################
    # For more details, see: https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.txt
    # Disable Firewall
# systemctl disable firewalld && systemctl stop firewalld
    # Posts to be defined on the worker nodes
    # All       kube-apiserver host     Incoming        Often TCP 443 or 6443*
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
    # Used by: kube-apiserver, etcd
    # etcd datastore    etcd hosts      Incoming        Officially TCP 2379 but can vary
firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
    # Used by: self, Control plane
firewall-cmd --zone=public --add-port=10250/tcp --permanent
    # Used by: self
firewall-cmd --zone=public --add-port=10251/tcp --permanent
    # Used by: self
firewall-cmd --zone=public --add-port=10252/tcp --permanent
    # Calico networking (BGP)   All     Bidirectional   TCP 179
firewall-cmd --zone=public --add-port=179/tcp --permanent
    # Calico networking with IP-in-IP enabled (default) All     Bidirectional   IP-in-IP, 4
firewall-cmd --zone=public --add-port=4/tcp --permanent
    # Calico networking with VXLAN enabled      All     Bidirectional   UDP 4789
firewall-cmd --zone=public --add-port=4789/tcp --permanent
    # Calico networking with Typha enabled      Typha agent hosts       Incoming        TCP 5473 (default)
firewall-cmd --zone=public --add-port=5473/tcp --permanent
    # Reload firewall
firewall-cmd --reload
    # List ports
echo
echo "Ports assignments: "
firewall-cmd --zone=public --permanent --list-ports
sleep 3
wait $!
}
###############################################################################
###############################################################################
#               INITIAL SETUP OF CLUSTER
###############################################################################
function setup() {
get_env k8s.env.example
###############################################################################
    # Reset IP tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
    # Pre-requisites Update /etc/hosts So that we can talk to each of the
    # nodes in the cluster
cat >/etc/hosts<<EOF
127.0.0.1 localhost
::1 localhost
${MASTER_NODE} k8s-master.example.com k8s-master
${WORKER_NODE_1} k8s-worker-node-1.example.com k8s-worker-node-1
${WORKER_NODE_2} k8s-worker-node-2.example.com k8s-worker-node-2
EOF

    # Setup firewall rules
    # Posts to be defined on the worker nodes
    # Run firewall function:
firewall_rules

    # Disable swap
swapoff -a && sed -i '/swap/d' /etc/fstab
wait $!

    # Disable SELinux
setenforce 0
sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
wait $!

    # Update sysctl settings for Kubernetes networking
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
wait $!

    # Install docker engine
yum install -y yum-utils device-mapper-persistent-data lvm2     > /dev/null 2>&1
yum-config-manager \
--add-repo https://download.docker.com/linux/centos/docker-ce.repo  > /dev/null 2>&1
wait $!

yum update -y && yum install -y \
containerd.io-1.3.7 \
docker-ce-19.03.13 \
docker-ce-cli-19.03.13 >/dev/null 2>&1
systemctl enable --now docker
wait $!

    # Create /etc/docker
mkdir /etc/docker
    # Set up the Docker daemon
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "250m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
    # Enable & Restart Docker
systemctl daemon-reload
systemctl restart docker
systemctl enable docker
wait $!


    # Kubernetes Setup Add yum repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

    # Install Kubernetes components
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
wait $!

    # Enable and Start kubelet service
systemctl enable --now kubelet
systemctl start kubelet
wait $!

    # On kmaster
    # Initialize Kubernetes Cluster
echo & ${KUBEADM} init --apiserver-advertise-address=${APISERVER_ADVERTISE_ADDRESS} \
--pod-network-cidr=${__POD_NETWORK_CIDR_}

    # Setup KUBECONFIG file:
mkdir -p ${__KUBECONFIG_DIRECTORY__}/.kube
cp -i /etc/kubernetes/admin.conf  ${__KUBECONFIG_DIRECTORY__}/config
chown ${K8S_USER}:${K8S_USER}  ${__KUBECONFIG_DIRECTORY__}/config
wait $!

    # Deploy Calico network
    # Source: https://docs.projectcalico.org/v3.14/manifests/calico.yaml
    # Modify the config map as needed:
echo & ${KUBECTL} --kubeconfig=${__KUBECONFIG_FILEPATH__} create -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml
    # Cluster join command
echo & ${KUBEADM} token create --print-join-command
exit 0
}   # END OF SETUP
###############################################################################
###############################################################################
#               RESET CLUSTER
###############################################################################
function reset(){
get_env k8s.env.example
###############################################################################
    # Verify kubeadm and kubectl binary
kube_binary
    # Reset Master Node
echo && ${KUBEADM} reset
wait $!
    # Reset IP tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
wait $!
    ###########################################################################
    # Deleting contents of config directories:
    # [/etc/kubernetes/manifests /etc/kubernetes/pki] Deleting files:
    # [/etc/kubernetes/admin.conf /etc/kubernetes/kubelet.conf
    # /etc/kubernetes/bootstrap-kubelet.conf /etc/kubernetes/controller-manager.conf
    # /etc/kubernetes/scheduler.conf] Deleting contents of stateful directories:
    # [/var/lib/etcd /var/lib/kubelet /var/lib/dockershim /var/run/kubernetes
    # /var/lib/cni]
rm -rf \
/etc/kubernetes/manifests \
/etc/kubernetes/pki \
/etc/kubernetes/admin.conf \
/etc/kubernetes/kubelet.conf \
/etc/kubernetes/bootstrap-kubelet.conf \
/etc/kubernetes/controller-manager.conf \
/etc/kubernetes/scheduler.conf \
/var/lib/kubelet \
/var/lib/dockershim \
/var/run/kubernetes \
/var/lib/cni \
/etc/cni/net.d \
${__KUBECONFIG_DIRECTORY__}/config
wait $!


    # Restart the kubelet
systemctl daemon-reload &&
systemctl enable --now kubelet &&
systemctl restart kubelet &&
systemctl enable docker &&
systemctl restart docker
wait $!

    # On kmaster
    # Initialize Kubernetes Cluster
echo & ${KUBEADM} init --apiserver-advertise-address=${APISERVER_ADVERTISE_ADDRESS} \
--pod-network-cidr=${__POD_NETWORK_CIDR_}

    # Setup KUBECONFIG file:
mkdir -p ${__KUBECONFIG_DIRECTORY__}/.kube
cp -i /etc/kubernetes/admin.conf  ${__KUBECONFIG_DIRECTORY__}/config
chown ${K8S_USER}:${K8S_USER}  ${__KUBECONFIG_DIRECTORY__}/config
wait $!

    # Deploy Calico network
    # Source: https://docs.projectcalico.org/v3.14/manifests/calico.yaml
    # Modify the config map as needed:
echo & ${KUBECTL} --kubeconfig=${__KUBECONFIG_FILEPATH__}  create -f https://docs.projectcalico.org/v3.14/manifests/calico.yaml
    # Cluster join command
echo & ${KUBEADM} token create --print-join-command
exit 0
}   # END OF RESET
###############################################################################
###############################################################################
###############################################################################
function get_env(){
###############################################################################
# Local .env
if [ -f $1 ]; then
    # Load Environment Variables
    export $(cat $1 | grep -v '#' | awk '/=/ {print $1}')
fi
Checking if environments have loaded
echo "Master Node address: ${MASTER_NODE}"
echo "Worker node 1 address: ${WORKER_NODE_1}"
echo "Worker node 2 address: ${WORKER_NODE_2}"
echo "Kubernetes API Address: ${APISERVER_ADVERTISE_ADDRESS}"
echo "Kubernetes POD CIDR: ${__POD_NETWORK_CIDR__}"
echo "User Home Directory: ${USER_HOME}"
echo "User: ${K8S_USER}"
echo "Kubernetes config file PATH: ${KUBECONFIG}"
echo "Kubernetes Service Port: ${__KUBERNETES_SERVICE_PORT__}"
echo "Calico file directory: ${__CALICO_YAML_DIRECTORY__}"
echo "Kubeconfig directory: ${__KUBECONFIG_DIRECTORY__}"
echo "Kubeconfig file path: ${__KUBECONFIG_FILEPATH__}"
}
###############################################################################
###############################################################################
###############################################################################
function check_env() {
###############################################################################
        ## Check envirnoment variable
if [[ -z "$1" ]]; then
        printf "\n$2 NULL\n" 1>/dev/null 2>/dev/null
        return ""
else
        printf "\n$2 $1\n" 1>/dev/null 2>/dev/null
        echo "$1"
fi
}
###############################################################################
###############################################################################
###############################################################################
function test_input() {
###############################################################################
    ## Exit if no paramaters provided
i=0
in="$1"
while [[ "${in}" != "reset" && "${in}" != "setup" && -z "${in}" ]];
do
        printf "\nInitial Usage:${RED} $0 [ reset | setup ]${NC}\n";
        printf "\nEnter a task parameter => ${RED} $0 [ reset | setup ]${NC} to reset or setup master node: ";
        in=$(read v && echo ${v})
        sleep 1
        ((i++))
        if [[ "${i}" == 3 ]]; then
                exit 1
        fi
done

    ## Check the input command
in=$(check_env "${in}" "You entered: ")
    ## Check if command is valid
if [ "${in}" == "reset" ]; then
        reset
elif [ "${in}" == "setup" ]; then
        setup
elif [ "${in}" == "test" ]; then
        printf "\nTest was successful...\n";
        declare -x JOIN_TOKEN=$(read -p 'Please enter kubeadm join token: ' v && echo $v)
        declare -x JOIN_TOKEN=$(check_env "${JOIN_TOKEN}" "You entered: ")
        printf "\nJoin Token Set to: ${JOIN_TOKEN}\n"
        exit 0
else
        echo ""
        printf "${RED}\"${in}\"${NC} is not a valid option...\n";
        printf "\nUsage: ${RED}${0} [ setup | reset ]${NC}\n";
        printf "\nThis script will exit after two failed attempts...\n";

        if [ "${i}" == 3 ]; then
                exit 1
        fi

        test_input
fi

}
###############################################################################
###############################################################################
###############################################################################
test_input $1