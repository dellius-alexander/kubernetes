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
    printf  "\nUnable to locate ${RED}kubeadm${NC} binary. \nPlease re-run this script using \
            the ${RED}--setup${NC} flag.\n Usage:${RED} $0 [ --reset | --setup ]${NC}\n";
    printf "\n${RED}sudo $0 $*${NC}";
    exit 1
elif [[ -z ${KUBECTL} ]]; then
        printf "\nUnable to locate ${RED}kubelet${NC} binary. \nPlease re-run this script using the \
                ${RED}--setup${NC} flag.\n Usage:${RED} $0 [ --reset | --setup ]${NC}\n";
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
        # Worker node(s)
        # Protocol	Direction	Port Range	Purpose	Used By	
        # TCP	Inbound	10250	Kubelet API	Self, Control plane	
        # TCP	Inbound	30000-32767	NodePort Services†	All

        # For more details, see: 
        # https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.txt
        # Disable Firewall
        # systemctl disable firewalld && systemctl stop firewalld
        # Posts to be defined on the worker nodes
        # Used by: self, Control plane
firewall-cmd --zone=public --add-port=10250/tcp --permanent
        # Used by: self, Control plane
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
        # Reload firewall
firewall-cmd --reload
        # List ports
echo
echo "Ports assignments: "
firewall-cmd --zone=public --permanent --list-ports
wait $!
}
###############################################################################
###############################################################################
###############################################################################
#               INITIAL SETUP OF CLUSTER NODE
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

        #####################################################################
        # Join node to master
join "$1"
exit 0
}
###############################################################################
###############################################################################
#          GET ENVIRONMENT VARIABLE FROM .env FILE
###############################################################################
function get_env(){
###############################################################################
# Local .env
if [ -f $1 ]; then
    # Load Environment Variables
    export $(cat $1 | grep -v '#' | awk '/=/ {print $1}')
else
    printf "${RED}Unable to load file.  Check your input and rerun again...${NC}\n"
    exit $?
fi
}
###############################################################################
###############################################################################
#       CHECK IF ENVIROMENT VARIABLE EXISTS
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
#              JOIN FUNCTION
###############################################################################

        # Join this cluster to a k8s master node
function join()
{
status=""
        ## Just join the cluster
if [[ -z ${__JOIN_TOKEN__} ]]; then
        printf "\n${RED}Kubeadm join token is not set...${NC}\n"
        test_input "join"
else
        echo & ${__JOIN_TOKEN__}  2>/dev/null &&

        wait $!
        if [ "$?" != 0 ]; then
                printf "\n${RED}ERROR: ${NC}Kubeadm join token return ${RED}${?}${NC}\n"
                test_input "join"
        fi
fi
wait $!
 }
###############################################################################
###############################################################################
###############################################################################
#               RESET NODE
###############################################################################
function reset()
{
printf "User: ${K8S_USER} \nHome Directory: $USER_HOME\n"
if [[ -z ${__JOIN_TOKEN__} ]]; then
        printf "This scripts requires you set environment variable for kubernetes join token.  \
                \nThe format for the token should be exported in the current running shell as an environment variable. \
                Such as: \n\t${RED}export __JOIN_TOKEN__=<k8s join token> ${NC}\n";
        printf "\tEx: \n\t ${RED}export __JOIN_TOKEN__='kubeadm join 10.0.0.129:6443 --token 6rvyd6.ej0wp9hvm7o6ybpe \
                \n\t --discovery-token-ca-cert-hash sha256:828ce1659093eb90f310956a8b0821f381cad388fac8686af3390e55c545b053'${NC} \n"
        printf "You may need to run the command on your master node to get the join token, like: 
                \n\t${RED}kubeadm token create --print-join-command ${NC}\n"
        printf "\nTry again after you set: ${RED}__JOIN_TOKEN__=<Join command token>${NC}\n\n"
        exit 1
else

        printf "${RED}Kubernetes join command set ${NC} \nSetting up working node now...\n\n"

fi

        #####################################################################
        # Restart Master Node
echo & ${KUBEADM} reset
wait $!
        #####################################################################
        # Deleting contents of config directories:
        # [/etc/kubernetes/manifests /etc/kubernetes/pki]
        # Deleting files:
        # [/etc/kubernetes/admin.conf
        # /etc/kubernetes/kubelet.conf /etc/kubernetes/bootstrap-kubelet.conf
        # /etc/kubernetes/controller-manager.conf /etc/kubernetes/scheduler.conf] Deleting contents of
        # stateful directories: [/var/lib/etcd /var/lib/kubelet /var/lib/dockershim /var/run/kubernetes
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
~/.kube/config
wait $!
        # The reset process does not reset or clean up iptables rules or IPVS tables.
        # If you wish to reset iptables, you must do so manually by using the "iptables" command.
        # If your cluster was setup to utilize IPVS, run ipvsadm --clear (or similar)
        # to reset your system's IPVS tables.
        #####################################################################
/usr/sbin/ipvsadm --clear
wait $!
        #####################################################################
        # Posts to be defined on the worker nodes
        # Used by: Self, Control plane
firewall-cmd --zone=public --add-port=10250/tcp --permanent
        # Used by: All
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
firewall-cmd --reload
wait $!
        #####################################################################
        # Restart the kubelet
systemctl enable kubelet
systemctl restart kubelet
systemctl daemon-reload
systemctl restart docker
systemctl enable docker
wait $!
        #####################################################################
        # Join node to master
join "$1"
exit 0
}
###############################################################################
###############################################################################
#                       check_env function
###############################################################################
function check_env()
{
## Check envirnoment variable
if [[ -z "$1" ]]; then
        printf "\n$2 NULL\n" 1>/dev/null 2>/dev/null
        return ""
else
        printf "\n$2 $1\n" 1>/dev/null 2>/dev/null
        echo "$1"
fi
exit 0
}
###############################################################################
###############################################################################
#                  TEST THE INPUT PARAMETERS
###############################################################################
function test_input()
{
        ## Exit if no paramaters provided
i=0
in="$1"
while [[ "$in" != "test" && "$in" != "create" && "$in" != "reset" && "$in" != "join" && -z "${in}" ]];
do
        printf "\nInitial Usage:${RED} $0  [ create | reset | join ]${NC}\n";
        printf "\nEnter a task parameter => ${RED}[ create | reset | join ]${NC} \
to reset, join or create a worker node:  ";
in=$(read v && echo ${v})
sleep 0.5
done
        ## Check the input command
in=$(check_env "${in}" "You entered: ")
        ## Check if command is valid
if [ "${in}" == "reset" ]; then
        declare -x __JOIN_TOKEN__=$(read -p 'Please enter kubeadm join token: ' v && echo $v)
        declare -x __JOIN_TOKEN__=$(check_env "${__JOIN_TOKEN__}" "You Entered: ")
        printf "\nJoin Token Set to: ${__JOIN_TOKEN__}\n"
        reset "${__JOIN_TOKEN__}"
elif [ "${in}" == "join" ]; then
        declare -x __JOIN_TOKEN__=$(read -p 'Please enter kubeadm join token: ' v && echo $v)
        declare -x __JOIN_TOKEN__=$(check_env "${__JOIN_TOKEN__}" "You Entered: ")
        printf "\nJoin Token Set to: ${__JOIN_TOKEN__}\n"
        join "${__JOIN_TOKEN__}"
elif [ "${in}" == "create" ]; then
        declare -x __JOIN_TOKEN__=$(read -p 'Please enter kubeadm join token: ' v && echo $v)
        declare -x __JOIN_TOKEN__=$(check_env "${__JOIN_TOKEN__}" "You Entered: ")
        printf "\nJoin Token Set to: ${__JOIN_TOKEN__}\n"
        create "${__JOIN_TOKEN__}"
elif [ "${in}" == "test" ]; then
        declare -x __JOIN_TOKEN__=$(read -p 'Please enter kubeadm join token: ' v && echo $v)
        declare -x __JOIN_TOKEN__=$(check_env "${__JOIN_TOKEN__}" "You entered: ")
        printf "\nJoin Token Set to: ${__JOIN_TOKEN__}\n"
        get_env k8s.env
        printf "\nTest was successful...\n";        
        exit 0
else
        echo ""
        printf "${RED}\"${in}\"${NC} is not a valid option...\n";
        printf "\nUsage: ${RED}${0} [ create | reset | join ]${NC}\n";
        printf "\nThis script will exit after two failed attempts...\n";
        if [[ $i == 2 ]]; then
                exit 0
        fi
        ((i++))
        test_input
fi
}
###############################################################################
###############################################################################
# START PROCESS
###############################################################################
###############################################################################
test_input "$1"