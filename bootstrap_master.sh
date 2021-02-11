#!/usr/bin/env bash
###############################################################################
###############################################################################
###############################################################################
    # Verify kubelet present on host
KUBEADM=$(command -v kubeadm)
KUBECTL=$(command -v kubectl)
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
########################    GET ENVIRONMENT FILE    ###########################
###############################################################################
function get_env(){
###############################################################################
# Local .env
if [ -f $1 ]; then
    # Load Environment Variables
    export $(cat $1 | grep -v '#' | awk '/=/ {print $1}')
else
    printf "${RED}Unable to load file. Check your input and rerun again...${NC}\n"
    exit $?
fi
    # Checking if environment variables have loaded
echo "Master Node address: ${__MASTER_NODE__}"
echo "Worker node 1 address: ${__WORKER_NODE_1__}"
echo "Worker node 2 address: ${__WORKER_NODE_2__}"
echo "Kubernetes API Address: ${__APISERVER_ADVERTISE_ADDRESS__}"
echo "Kubernetes POD CIDR: ${__POD_NETWORK_CIDR__}"
echo "User Home Directory: ${__USER_HOME__}"
echo "User: ${__USER__}"
echo "Kubernetes config file PATH: ${__KUBECONFIG__}"
echo "Kubernetes Service Port: ${__KUBERNETES_SERVICE_PORT__}"
echo "Kubeconfig directory: ${__KUBECONFIG_DIRECTORY__}"
echo "Kubeconfig file path: ${__KUBECONFIG_FILEPATH__}"
}   # End of get_env
###############################################################################
###############################################################################
#####################     CHECK ENVIRONMENT VARIABLE      #####################
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
}   # End of check_env
###############################################################################
###############################################################################
################     VERIFY KUBEADM AND KUBECTL BINARIES     ##################
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
}   # End of kube_binary check
###############################################################################
###############################################################################
#########################    SETUP FIREWALL RULES    ##########################
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
wait $!
printf "\n${RED}Ports assignments: ${NC}\n"
firewall-cmd --zone=public --permanent --list-ports
printf "\n\n"
sleep 3
wait $!
}   # End of firewall_rules
###############################################################################
###############################################################################
#####################    INITIALIZE CLUSTER COMPONENTS    #####################
###############################################################################
function init_cluster() {
###############################################################################
    # On kmaster
    # Initialize Kubernetes Cluster
${KUBEADM} init --apiserver-advertise-address=${__APISERVER_ADVERTISE_ADDRESS__} \
--pod-network-cidr=${__POD_NETWORK_CIDR__}

    # Setup KUBECONFIG file:
mkdir -p ${__KUBECONFIG_DIRECTORY__}
cp -i /etc/kubernetes/admin.conf  ${__KUBECONFIG_DIRECTORY__}/config
chown ${__USER__}:${__USER__}  ${__KUBECONFIG_DIRECTORY__}/config
wait $!

    # Deploy Calico network
    # Source: https://docs.projectcalico.org/v3.14/manifests/calico.yaml
    # Modify the config map as needed:
printf "\n\n${RED}--Deploying Calico Networking...${NC}\n\n"
${KUBECTL} --kubeconfig=${__KUBECONFIG__}  create -f $(find ~+ -type f -name 'calico.yaml')
#${KUBECTL} --kubeconfig=${__KUBECONFIG_FILEPATH__}  create -f https://docs.projectcalico.org/manifests/calico.yaml
wait $!

    # Metric Server
printf "\n\n${RED}--Deploying Metric Server Daemonset...${NC}\n\n"
${KUBECTL} --kubeconfig=${__KUBECONFIG__}  apply -f $(find ~+ -type f -name 'metric-server.yaml')
wait $!

    # Cluster join command
printf "\n\n${RED}--Printing join token...${NC}\n\n"
${KUBEADM} token create --print-join-command
wait $!

}     # End of init_cluster
###############################################################################
###############################################################################
#########################     TEARDOWN CLUSTER     ############################
###############################################################################
function __teardown__(){
###############################################################################
get_env k8s.env

    # Verify kubeadm and kubectl binary
kube_binary

    # Reset Master Node
${KUBEADM} reset
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
systemctl stop kubelet &&
systemctl enable docker &&
systemctl restart docker
wait $!
}   # END OF TEARDOWN
###############################################################################
###############################################################################
#####################    INITIAL SETUP OF CLUSTER NODE    #####################
###############################################################################
function setup() {
###############################################################################
get_env k8s.env
###############################################################################
    # Install dependencies
yum install -y git nano net-tools firewalld nfs-utils
wait $!

    # Reset IP tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X

    # Pre-requisites: 
    # Update /etc/hosts file So that we can talk to each of the
    # nodes in the cluster. 
cat hosts.conf > /etc/hosts

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
cat >/etc/sysctl.d/kubernetes.conf<<EOF
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

yum install -y \
containerd.io-1.3.7 \
docker-ce-${__DOCKER_VERS__} \
docker-ce-cli-${__DOCKER_VERS__} >/dev/null 2>&1
systemctl enable --now docker
wait $!

if [ ! -d "/etc/docker/" ]; then
    # Create /etc/docker
    mkdir /etc/docker
fi
    # Set up the Docker daemon
cat daemon.json > /etc/docker/daemon.json 

    # Create docker service
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

    # Initialize Cluster
init_cluster

exit 0
}   # END OF SETUP
###############################################################################
###############################################################################
###########################    RESET CLUSTER     ##############################
###############################################################################
function reset(){
###############################################################################
    # Teardown Cluster
__teardown__

    # Initialize Cluster
init_cluster

exit 0
}   # END OF RESET
###############################################################################
###############################################################################
######################    TEST THE INPUT PARAMETERS    ########################
###############################################################################
function test_input() {
###############################################################################
    ## Exit if no paramaters provided
i=0
in="$1"
while [[ "${in}" != "reset" && "${in}" != "setup" && -z "${in}" ]];
do
    printf "\nInitial Usage:${RED} $0 [ setup | reset | stop ]${NC}\n";
    printf "\nEnter a task parameter => ${RED} $0 [ reset | setup | stop ]${NC} to \
setup, reset or teardown the master node: ";
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
    exit 0
elif [ "${in}" == "setup" ]; then
    setup
    exit 0
elif [ "${in}" == "test" ]; then
    get_env k8s.env
    printf "\nTest was successful...\n";        
    exit 0
elif [ "${in}" == "stop" ]; then
    printf "\n\n${RED}TEARING DOWN CLUSTER: ${NC}${HOSTNAME}\n\n"
    __teardown__
    printf "\n\n${RED}Node: ${HOSTNAME} restored to normal...${NC}\n\n"
    exit 0
else
    echo ""
    printf "${RED}\"${in}\"${NC} is not a valid option...\n"
    printf "\nUsage: ${RED}${0} [ setup | reset | stop ]${NC}\n"
    printf "\nNote: \"$0 stop\" command will teardown the node and revert node back to original state...\n"

    if [ "${i}" == 3 ]; then
            exit 1
    fi

    test_input
fi

}   # End of test_input
###############################################################################
###############################################################################
###############################################################################
test_input $1
###############################################################################
