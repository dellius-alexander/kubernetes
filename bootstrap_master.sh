#!/usr/bin/env bash
######################################################################################################################################################################################################
##################################################################################################
# PREREQUISITES: Install a (container runtime): this document
# uses docker container runtime.
###################################################################################################
# Install kubernetes cluster using kubeadm
###################################################################################################
#               Defined environmental variables
###################################################################################################
declare -x APISERVER_ADVERTISE_ADDRESS=${KUBERNETES_SERVICE_HOST}   # host IP: '10.0.0.129'
echo "Kubernetes API Address: $APISERVER_ADVERTISE_ADDRESS"
declare -x POD_NETWORK_CIDR="192.168.0.0/16"
echo "Kubernetes POD CIDR: $POD_NETWORK_CIDR"
declare -x USER_HOME=${USERHOME}
echo "User Home Directory: $USER_HOME"
declare -x K8S_USER=${USER}   # User: '1000'
echo "User: $K8S_USER"
declare -x __KUBERNETES_NODE_NAME__=${K8S_NODE_NAME}     # k8s node name: "k8s-master"
echo "Kubernetes Node Name: ${__KUBERNETES_NODE_NAME__}"
declare -x __KUBECONFIG_FILEPATH__=${KUBECONFIG_FILEPATH}   # kubeconfig file: "${USER_HOME}/.kube/config"
echo "Kubernetes config file PATH: ${__KUBECONFIG_FILEPATH__}"
declare -x __CNI_MTU__=${CNI_MTU}           # cni mtu: '1500'
echo "Container CNI MTU: ${__CNI_MTU__}"
declare -x __KUBERNETES_SERVICE_HOST__=${KUBERNETES_SERVICE_HOST}   # host IP: '10.0.0.129'
echo "Kubernetes Service Host: ${__KUBERNETES_SERVICE_HOST__}"
declare -x __KUBERNETES_SERVICE_PORT__='6443'
echo "Kubernetes Service Port: ${__KUBERNETES_SERVICE_PORT__}"
declare -x __ETCD_ENDPOINTS__=${ETCD_ENDPOINTS}     # etc endpoin: 'https://127.0.0.1:2379'
echo "ETCD Endpoints: ${__ETCD_ENDPOINTS__}"
# KUBECONFIG environment variables
declare -x KUBECONFIG="${USER_HOME}/.kube/config"
echo "KUBECONFIG=${KUBECONFIG}"
RED='\033[0;31m' # Red
NC='\033[0m' # No Color CAP
###################################################################################################
# Follow this documentation to set up a Kubernetes cluster on CentOS 7 Virtual machines.
#
# This documentation guides you in setting up a cluster with one master node and one worker
# node.
#########################################################
# [dalexander@k8s-master hyfi-nginx-demo]$ cat /etc/hosts 127.0.0.1 localhost
# ::1 localhost
# 10.0.0.90 k8s-master.example.com k8s-master 10.0.0.91 k8s-worker.example.com
# k8s-worker-node-1
#########################################################
# Assumptions Role FQDN IP OS RAM CPU Master k8s-master.example.com 172.42.42.99 CentOS 7 4G 4
# Worker k8s-worker.example.com 172.42.42.110 CentOS 7 4G 4 On both k8s-master and k8s-worker
# Perform all the commands as root user unless otherwise specified
##########################################################################
#                                       Gets and validates user input Parameter:
# Query/Question
function get_value() { 
bool=true 
QUERYt=${1}
# Enters the prompt message and returns the user input
while [ "$bool" == true ]; do
        RESPONSE=$(echo "${QUERY}" 2> /dev/null <&1)
        printf "\nYou entered: ${RESPONSE}\n" 1>/dev/null 2>/dev/null
        ANSWER=$(read -p 'Verify your submission and ENTER, [R]esubmit | [C]o ntinue: ' v &&
echo ${v})
        if [ "${ANSWER}" == "C" ] || [ "${ANSWER}" == "c" ]; then
                printf "\nLets continue...\n" 1>/dev/null 2>/dev/null
                sleep 0.5
                bool=false
        elif [ "${ANSWER}" == "R" ] || [ "${ANSWER}" == "r" ]; then
                printf "\nLets try again...\n" 1>/dev/null 2>/dev/null
                bool=true
        fi done
}
function setup() {
        ###################################################################################################
        # Pre-requisites Update /etc/hosts So that we can talk to each of the nodes in the
        # cluster
cat >/etc/hosts<<EOF
127.0.0.1 localhost
::1 localhost
10.0.0.129 k8s-master.example.com k8s-master
10.0.0.130 k8s-worker-node-1.example.com k8s-worker-node-1
10.0.0.131 k8s-worker-node-2.example.com k8s-worker-node-2
EOF
wait $!
        ###################################################################################################
        ###################################################################################################
        # Container runtimes FEATURE STATE: Kubernetes v1.6 [stable] To run containers in
        # Pods, Kubernetes uses a container runtime. Here are the installation instructions
        # for various runtimes. Popular Container Runtimes: Docker CRI-O Containerd Caution: A
        # flaw was found in the way runc handled system file descriptors when running
        # containers. A malicious container could use this flaw to overwrite contents of the
        # runc binary and consequently run arbitrary commands on the container host system.
        # Please refer to CVE-2019-5736 (https://access.redhat.com/security/cve/cve-2019-5736)
        # for more information about the issue. Applicability Note: This document is written
        # for users installing CRI onto Linux. For other operating systems, look for
        # documentation specific to your platform. You should execute all the commands in this
        # guide as root. For example, prefix commands with sudo, or become root and run the
        # commands as that user. Cgroup drivers When systemd is chosen as the init system for
        # a Linux distribution, the init process generates and consumes a root control group
        # (cgroup) and acts as a cgroup manager. Systemd has a tight integration with cgroups
        # and will allocate cgroups per process. Its possible to configure your container
        # runtime and the kubelet to use cgroupfs. Using cgroupfs alongside systemd means that
        # there will be two different cgroup managers. Control groups are used to constrain
        # resources that are allocated to processes. A single cgroup manager will simplify the
        # view of what resources are being allocated and will by default have a more
        # consistent view of the available and in-use resources. When we have two managers we
        # end up with two views of those resources. We have seen cases in the field where
        # nodes that are configured to use cgroupfs for the kubelet and Docker, and systemd
        # for the rest of the processes running on the node becomes unstable under resource
        # pressure. Changing the settings such that your container runtime and kubelet use
        # systemd as the cgroup driver stabilized the system. Please note the
        # native.cgroupdriver=systemd option in the Docker setup below. Caution: Changing the
        # cgroup driver of a Node that has joined a cluster is highly unrecommended. If the
        # kubelet has created Pods using the semantics of one cgroup driver, changing the
        # container runtime to another cgroup driver can cause errors when trying to re-create
        # the PodSandbox for such existing Pods. Restarting the kubelet may not solve such
        # errors. The recommendation is to drain the Node from its workloads, remove it from
        # the cluster and re-join it. Docker On each of your machines, install Docker. Version
        # 19.03.8 is recommended, but 1.13.1, 17.03, 17.06, 17.09, 18.06 and 18.09 are known
        # to work as well. Keep track of the latest verified Docker version in the Kubernetes
        # release notes. Use the following commands to install Docker on your system: On
        # CentOS/RHEL 7.4+ (Install Docker CE) Install, enable and start docker service Use
        # the Docker repository to install docker. NOTE: If you use docker from CentOS OS
        # repository, the docker version might be old to work with Kubernetes v1.13.0 and
        # above Set up the repository Install required packages
yum install -y yum-utils device-mapper-persistent-data lvm2 > /dev/null 2>&1
wait $!
        # Add the Docker repository
yum-config-manager --add-repo \ https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
wait $!
        # Install Docker CE
yum install -y \
containerd.io-1.2.13 \
docker-ce-19.03.8 \
docker-ce-cli-19.03.8 >/dev/null 2>&1
wait $!
        # Create /etc/docker
mkdir /etc/docker
        # Set up the Docker daemon
cat <<EOF | tee /etc/docker/daemon.json { "exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file", "log-opts": {
    "max-size": "100m"
},
"storage-driver": "overlay2", "storage-opts": [
    "overlay2.override_kernel_check=true" ]
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
        # Enable & Restart Docker
systemctl daemon-reload
systemctl enable docker
systemctl restart docker
wait $!
        ###################################################################################################
        # Disable SELinux
        #
setenforce 0 sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' \
/etc/sysconfig/selinux
wait $!
        #
        ###################################################################################################
        # Disable Firewall instead of setting rules but this will leave you wide open
        #
        # systemctl disable firewalld systemctl stop firewalld
        ###################################################################################################
        #             [SECURED OPTION]: SET firewall rules (currently not working properly) #
        ###################################################################################################
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
firewall-cmd --zone=public --add-port=10250/tcp --permanent
firewall-cmd --zone=public --add-port=10251/tcp --permanent
firewall-cmd --zone=public --add-port=10252/tcp --permanent
firewall-cmd --zone=public --add-port=10255/tcp --permanent
firewall-cmd --reload
wait $!
        ###################################################################################################
        # Disable swap
        #
sed -i '/swap/d' /etc/fstab swapoff -a
        #
        # Update sysctl settings for Kubernetes networking Set the
        # net.bridge.bridge-nf-call-iptables to 1 in your sysctl config file. This ensures
        # that packets are properly processed by IP tables during filtering and port
        # forwarding.
cat >/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
wait $!
        ###################################################################################################
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

# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
                # Install Kubernetes
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
wait $!

        # Enable and Start kubelet service
systemctl enable --now kubelet
systemctl start kubelet
wait $!
        #
        # On k8s-master Initialize Kubernetes Cluster
/usr/bin/kubeadm init --pod-network-cidr=${POD_NETWORK_CIDR}
wait $!
        #
mkdir -p ${USER_HOME}/.kube
cp -i /etc/kubernetes/admin.conf /home/dalexander/.kube/config
chown ${K8S_USER}:${K8S_USER} ${USER_HOME}/.kube/config
wait $!
        ###################################################################################################
        # Copy kube config To be able to use kubectl command to connect and interact with the
        # cluster as non-root user, the user needs kube config file placed in their $HOME
        # directory and sudo privileges given to access config files In my case, the user
        # account is dalexander: (the below must be run as non-root user) Your Kubernetes
        # control-plane has initialized successfully! To start using your cluster, you need to
        # run the following as a regular user: mkdir -p $HOME/.kube sudo cp -i
        # /etc/kubernetes/admin.conf $HOME/.kube/config sudo chown $(id -u):$(id -g)
        # $HOME/.kube/config You should now deploy a pod network to the cluster. Run "kubectl
        # apply -f [podnetwork].yaml" with one of the options listed at:
        # https://kubernetes.io/docs/concepts/cluster-administration/addons/ Then you can join
        # any number of worker nodes by running the following on each as root:
        # #############################################
        # #### Get join command for worker nodes #### #
        # kubeadm token create --print-join-command
        # ##############################################
        # kubeadm join 172.17.10.99:6443 --token h8fslw.2j0paprsp915fsy6 \
        #--discovery-token-ca-cert-hash
        #sha256:87f577690ce400b98861d83fe5b7286bdea09cf3b143083f09bc750aff44fe64
        ###################################################################################################
        ###################################################################################################
        # CNI network configuration template The cni_network_config configuration option
        # supports the following template fields, which will be filled in automatically by the
        # calico/cni container: Field Substituted with __KUBERNETES_SERVICE_HOST__ The
        # Kubernetes service Cluster IP, e.g 10.0.0.1 __KUBERNETES_SERVICE_PORT__ The
        # Kubernetes service port, e.g., 443 __SERVICEACCOUNT_TOKEN__ The service account
        # token for the namespace, if one exists. __ETCD_ENDPOINTS__ The etcd endpoints
        # specified in etcd_endpoints. __KUBECONFIG_FILEPATH__ The path to the automatically
        # generated kubeconfig file in the same directory as the CNI network configuration
        # file. __ETCD_KEY_FILE__ The path to the etcd key file installed to the host. Empty
        # if no key is present. __ETCD_CERT_FILE__ The path to the etcd certificate file
        # installed to the host, empty if no cert present. __ETCD_CA_CERT_FILE__ The path to
        # the etcd certificate authority file installed to the host. Empty if no certificate
        # authority is present.
        #####################################################################
        ###################################################################################################
        # Deploy Calico network This has to be done as the user in the above step (in my case
        #it is dalexander) Install Calico with the following command. kubectl apply -f
        #https://docs.projectcalico.org/manifests/calico.yaml
echo "Setting up Networking and Dashboard........."
sleep 2
/usr/bin/kubectl create -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml --kubeconfig=${KUBECONFIG}
wait $!
        # [OPTIONAL] kubectl create -f
        # https://docs.projectcalico.org/v3.11/manifests/calico.yaml
        ###################################################################################################
        # Cluster join command [OPTIONAL]: Use to create new kubeadm join token kubeadm token
        # create --print-join-command
        #
        # On Kworker Join the cluster Use the output from kubeadm token create command in
        # previous step from the master server and run here. [root@k8s-worker-node-1 /]#
        # kubeadm join 172.17.10.99:6443 --token h8fslw.2j0paprsp915fsy6 \
        # >      --discovery-token-ca-cert-hash
        # >      sha256:87f577690ce400b98861d83fe5b7286bdea09cf3b143083f09bc750aff44fe64
        # W0529 12:52:52.878673 4832 join.go:346] [preflight] WARNING:
        # JoinControlPane.controlPlane settings will be ignored when control-plane flag is not
        # set. [preflight] Running pre-flight checks [preflight] Reading configuration from
        # the cluster... [preflight] FYI: You can look at this config file with 'kubectl -n
        # kube-system get cm kubeadm-config -oyaml' [kubelet-start] Downloading configuration
        # for the kubelet from the "kubelet-config-1.18" ConfigMap in the kube-system
        # namespace [kubelet-start] Writing kubelet configuration to file
        # "/var/lib/kubelet/config.yaml" [kubelet-start] Writing kubelet environment file with
        # flags to file "/var/lib/kubelet/kubeadm-flags.env" [kubelet-start] Starting the
        # kubelet [kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap... This
        # node has joined the cluster: * Certificate signing request was sent to apiserver and
        # a response was received. * The Kubelet was informed of the new secure connection
        # details. Run 'kubectl get nodes' on the control-plane to see this node join the
        # cluster.
        ###################################################################################################
        # Verifying the cluster Get Nodes status kubectl get nodes Get component status
/usr/bin/kubectl get cs
        ###################################################################################################
	#		CREATE PRIVATE SECRET FOR PRIVATE IMAGE REGISTRY AND ASSIGN TO NAME SPACES
        ###################################################################################################
        # Add Gitlab Repository secrects Create environment variables for each object flag
        # using export <Environment variable Name>="<value>" Setup 2.1. Authenticate Private
        # Registry Create personal secret to authenticate pulling private images from Gitlab.
        ###################################################################################################
        # kubectl create secret docker-registry gitlab \
        #     --docker-server="https://registry.gitlab.com/clayton-state-university/" \
        # --docker-username=${USERNAME} \ --docker-password=${PASSWORD} \
        # --docker-email=${EMAIL} \ -o yaml --dry-run 
	# cat <<EOF | kubectl create -f -
        # apiVersion: v1 data:
        #   .dockerconfigjson: kind: Secret metadata: creationTimestamp: null name: gitlab
        # type: kubernetes.io/dockerconfigjson 
	# EOF
	###################  	TRANSFER SECRETS TO ANOTHER NAMESPACE	  ################################
	# Once created you can transfer secrets to any name space by using this command:
	# kubectl get secret <REGISTRY NAME> --namespace=<DEFAULT NAMESPACE> --export -o yaml |\
   	# kubectl apply --namespace=<THE OTHER NAMESPACE NAME YOU WANT TO TRANSFER TO> -f -
        ###################################################################################################
        # Copy and paste the output into a seperate file gitlab-secret.yaml. Then use the
        # following command to create the secret. kubectl create -f gitlab-secret.yaml
        # secret/gitlab created
/usr/bin/kubectl get nodes
wait $!
/usr/bin/kubectl get all --all-namespaces
wait $!
/usr/bin/kubeadm token create --print-join-command
wait $!
exit 0
}
###################################################################################################
#                                               reset function: reset cluster to base startup
#                                               state
###################################################################################################
function _reset() {
        #####################################################################
        # Restart Master Node
/usr/bin/kubeadm reset
wait $!
        #####################################################################
        # Update /etc/hosts So that we can talk to each of the nodes in the cluster
cat >/etc/hosts<<EOF
127.0.0.1 localhost
::1 localhost
10.0.0.129 k8s-master.example.com k8s-master
10.0.0.130 k8s-worker-node-1.example.com k8s-worker-node-1
10.0.0.131 k8s-worker-node-2.example.com k8s-worker-node-2
EOF
wait $!
        #####################################################################
        # Deleting contents of config directories:
        #       [/etc/kubernetes/manifests /etc/kubernetes/pki] Deleting files:
        # [/etc/kubernetes/admin.conf /etc/kubernetes/kubelet.conf
        # /etc/kubernetes/bootstrap-kubelet.conf /etc/kubernetes/controller-manager.conf
        # /etc/kubernetes/scheduler.conf] Deleting contents of stateful directories:
        # [/var/lib/etcd /var/lib/kubelet /var/lib/dockershim /var/run/kubernetes
        # /var/lib/cni]
rm -rf \
/var/lib/etcd/* \
/var/lib/kubelet/* \
/var/lib/dockershim/* \
/var/run/kubernetes/* \
/var/lib/cni/* \
/etc/cni/net.d \
/etc/kubernetes/manifests \
/etc/kubernetes/pki \
/etc/kubernetes/admin.conf \
/etc/kubernetes/kubelet.conf \
/etc/kubernetes/bootstrap-kubelet.conf \
/etc/kubernetes/controller-manager.conf \
/etc/kubernetes/scheduler.conf \
${USER_HOME}/.kube/config
wait $!
        #####################################################################
        # The reset process does not reset or clean up iptables rules or IPVS tables
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
        #/usr/sbin/ipvsadm --clear
        # [OPTIONAL]: SET firewall rules (currently not working properly)
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
firewall-cmd --zone=public --add-port=10250/tcp --permanent
firewall-cmd --zone=public --add-port=10251/tcp --permanent
firewall-cmd --zone=public --add-port=10252/tcp --permanent
firewall-cmd --zone=public --add-port=10255/tcp --permanent
firewall-cmd --reload
wait $!
#assign_port "6443" && \
#assign_port "2379" && \
#assign_port "2380" && \
#assign_port "30000-32767" && \
#assign_port "10250-10255"
        #####################################################################
        # Restart the kubelet
systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet
systemctl enable docker
systemctl restart docker
wait $!
        # Update sysctl settings for Kubernetes networking Set the
        # net.bridge.bridge-nf-call-iptables to 1 in your sysctl config file. This ensures
        # that packets are properly processed by IP tables during filtering and port
        # forwarding.
cat >/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system
        #####################################################################
        # Restart the cluster with the new apiserver-advertise-address
/usr/bin/kubeadm init --pod-network-cidr=192.168.0.0/16
wait $!
sleep 2
mkdir -p ${USER_HOME}/.kube
cp -i /etc/kubernetes/admin.conf ${USER_HOME}/.kube/config
chown ${K8S_USER}:${K8S_USER} ${USER_HOME}/.kube/config
wait $!
sleep 2
        ##  Setup Networking with Calico manifest
echo "Setting up Networking and Dashboard........."
sleep 2
/usr/bin/kubectl create -f https://docs.projectcalico.org/v3.11/manifests/calico.yaml --kubeconfig=${KUBECONFIG}
wait $!
sleep 2
        #/usr/bin/kubectl apply -f
        #https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.1/aio/deploy/recommended.yaml
        #--kubeconfig=${KUBECONFIG} wait $! sleep 2
        # Setup dashboard user cat <<EOF | /usr/bin/kubectl apply -f - apiVersion: v1 kind:
        #ServiceAccount metadata:
        #  name: admin-user namespace: kubernetes-dashboard EOF wait $! Configure RBAC for
        # user: admin-user cat <<EOF | /usr/bin/kubectl apply -f - apiVersion:
        # rbac.authorization.k8s.io/v1 kind: ClusterRoleBinding metadata:
        #  name: admin-user roleRef: apiGroup: rbac.authorization.k8s.io kind: ClusterRole
        #name: cluster-admin subjects: - kind: ServiceAccount
        #  name: admin-user namespace: kubernetes-dashboard EOF wait $!
# Health check
/usr/bin/kubectl get cs
# Get nodes
/usr/bin/kubectl get nodes
wait $!
/usr/bin/kubectl get all --all-namespaces
wait $!
/usr/bin/kubeadm token create --print-join-command
wait $!
exit 0
}
##########################################################################
#                       Assign Port Numbers
#########################################################################
function assign_port()
{
#  Check if port number exists
if [ -z ${1} ]; then
        echo "You must provide a parameter. Please try again..."
        printf "\nUsage:${RED} $0 <port number>${NC}\n"
        exit 1
elif [ $(echo $(/usr/sbin/ss -tlnp | grep -c ${1})) -gt 0 ]; then
        printf "\n${RED}WARNING${NC}: Port number ${RED}${1}${NC} already assigned...\n"
        exit 1
else
        /usr/bin/sed -i "s/Port 22/&\nPort ${1}/" /etc/ssh/sshd_config &&
                sudo firewall-cmd --add-port=${1}/tcp --permanent &&
                sudo firewall-cmd --reload
        sleep 0.5
fi
wait $!
printf "\nPort number ${RED}${1}${NC} assigned...\n" &&
sleep 0.5
semanage port -a -t ssh_port_t -p tcp "${1}" &&
sleep 0.5
systemctl restart sshd
sleep 0.5
echo "Verifying port assignment: " &&
sleep 0.5
/usr/sbin/ss -tlnp | grep "${1}"
}
##########################################################################
#                       check_env function
##########################################################################
function check_env() {
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
##########################################################################
#                       test_input function
##########################################################################
function test_input() {
## Exit if no paramaters provided
i=0
in="$1"
while [[ "$in" != "reset" && "$in" != "setup" && -z "${in}" ]];
do
        printf "\nInitial Usage:${RED} $0 [ reset | setup ]${NC}\n";
        printf "\nEnter a task parameter => ${RED} $0 [ reset | setup ]${NC} to reset or setup master node: ";
in=$(read v && echo ${v})
sleep 0.5
done
## Check the input command
in=$(check_env "${in}" "You entered: ")
## Check if command is valid
if [ "${in}" == "reset" ]; then
        _reset
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
        printf "\nUsage: ${RED}${0} [ create | reset | join ]${NC}\n";
        printf "\nThis script will exit after two failed attempts...\n";
        if [[ $i == 2 ]]; then
                exit 0
        fi
        ((i++))
        test_input
fi
}
test_input $1
