#!/usr/bin/env bash
#
#####################################################################
#                      ENVIRONMENTT VARIABLES                       #
#####################################################################
# Define these variables of the master node
declare -x USER_HOME=${USERHOME}
declare -x K8S_USER=${USER}
JOIN_TOKEN=${KUBEADM_JOIN_TOKEN}
echo "Set: ${JOIN_TOKEN}"
KUBEADM=$(whereis kubeadm | gawk -c '{print $2}')
echo "Set: ${KUBEADM}"

RED='\033[0;31m'
NC='\033[0m' # No Color
#####################################################################
function join()
{
echo & $JOIN_TOKEN
exit 0
}
#####################################################################
function reset()
{
printf "User: ${K8S_USER} \nHome Directory: $USER_HOME\n"
#printf "JOIN_TOKEN=${JOIN_TOKEN}\n"
if [[ -z ${JOIN_TOKEN} ]]; then
        printf "This scripts requires you set environment variable for kubernetes join token.  \nThe format for the token should be exported in the current running shell as an environment variable.  Such as: \n\t${RED}export K8S_JOIN_TOKEN=<k8s join token> ${NC}\n"
        printf "\tEx: \n\t ${RED}export K8S_JOIN_TOKEN='kubeadm join 10.0.0.129:6443 --token 6rvyd6.ej0wp9hvm7o6ybpe \ \n\t --discovery-token-ca-cert-hash sha256:828ce1659093eb90f310956a8b0821f381cad388fac8686af3390e55c545b053'${NC} \n"
        printf "You may need to run the command on your master node to get the join token, like: \n\t${RED}kubeadm token create --print-join-command ${NC}\n"
        printf "\nTry again after you set: ${RED}K8S_JOIN_TOKEN=<Join command token>${NC}\n\n"
        exit 1
else

        printf "${RED}Kubernetes join command set ${NC} \nSetting up working node now...\n\n"

fi

#####################################################################
# Restart Master Node
/usr/bin/kubeadm reset
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
# Restart the kubelet
systemctl enable kubelet
systemctl restart kubelet
systemctl enable docker
systemctl restart docker
wait $!
#####################################################################
iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
#####################################################################
# Restart the cluster with the new apiserver-advertise-address
echo & ${JOIN_TOKEN}
exit 0
}

if [ ${1} == "reset" ]; then
        reset;
elif [ ${1} == "join" ]; then
        join;
else
        echo "Something went wrong...";
fi
