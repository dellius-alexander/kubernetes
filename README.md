# Kubernetes Installation

---
## Contents:

* [On Master Node](#Master_Node)
* [On Worker Node](#Worker_Node)

### Kubernetes Configuration bootstraps:
   - One Master Node
   - Two Worker Nodes
   
You can optionally add an NFS share server to your Cluster.  [Click Here for More Details](NFS_README.md)
    
***Note: Kubernetes setup for Bare Metal configuration of minimal CentOS 7 / RHEL 7 machines.***

---
---

## <h2 id="Master_Node">On Master</h2>

<br/>

### 1. Clone Repo and Edit k8s.env.example File:

<br/>

<div id="canvas-background">

```Bash
# Clone Repo
$ git clone https://github.com/dellius-alexander/kubernetes.git
$ cd kubernetes
# Rename k8s.env.example file to k8s.env
$ mv k8s.env.example k8s.env
```

</div>



<br/>

### 2. Edit the [***k8s.env***](k8s.env.example) file required configuration options:
<br/>

<div id="canvas-background">


```Bash
# Use nano or vi to edit the k8s.env file <values in brackets>
$ vi k8s.env
##### REQUIRED CONFIGURATION OPTIONS #####
#
__MASTER_NODE__=<Enter IP Address>    # Enter IP Address of master
__WORKER_NODE_1__=<Enter IP Address>    # Enter IP Address of worker 1
__WORKER_NODE_2__=<Enter IP Address>    # Enter IP Address of worker 2
__APISERVER_ADVERTISE_ADDRESS__=<Enter IP Address>    # Edit "same as master node"
__CNI_MTU__=1500
__CALICO_YAML_DIRECTORY__=~/calico
__CALICO_DISABLE_FILE_LOGGING__=info
__CALICO_IPV4POOL_CIDR__=/16
__CALICO_IPV4POOL_IPIP__=Always
__CALICO_IPV4POOL_VXLAN__=Never
__CALICO_NETWORKING_BACKEND__=bird
__DATASTORE_TYPE__=kubernetes
__K8S_API_ROOT__=http://<Master Node IP Address>:6443    # Edit "same as master node"
__KUBECONFIG__=~/.kube/config
__KUBECONFIG_FILEPATH__=/etc/kubernetes/admin.conf
__KUBECONFIG_DIRECTORY__=~/.kube
__KUBERNETES_NODE_NAME__=k8s-master
__KUBERNETES_SERVICE_HOST__=<Master Node IP Address>
__KUBERNETES_SERVICE_PORT__=6443
__NODENAME__=k8s-master
__POD_NETWORK_CIDR__=192.168.0.0/16
__USER__=${USER}
__USER_HOME__=~
#
##### OPTIONAL CONFIGURATION #####
#
__CNI_CONF_NAME__=
__CNI_NETWORK_CONFIG__=
__FELIX_DEFAULTENDPOINTTOHOSTACTION__=
__FELIX_HEALTHENABLED__=
__FELIX_IPV6SUPPORT__=
__FELIX_IPINIPMTU__=
__FELIX_LOGSEVERITYSCREEN__=
__FELIX_VXLANMTU__=
__SERVICEACCOUNT_TOKEN__=
__WAIT_FOR_DATASTORE__=
__USER_AUTH__=
~
~
"k8s.env" 0L, 0C
```

</div>

<br/>

### 3. Execute the [***bootstrap_master.sh***](bootstrap_master.sh) script:
<br/>

The bootstrap_master.sh file must be run as ***sudo*** and requires one of three parameter options:
* ***test***: dry run test for environment file
* ***setup***: first time setup of master node
* ***reset***: tear down, clean up and reset master node
<br/>

<div id="canvas-background">

```Bash
# This process will take several minutes to run
# Requires one of three parameters <test | setup | reset>
$ sudo ./bootstrap_master.sh <test | setup | reset>
```

</div>



If no errors occurs, we will need the ***kubernetes join token***  to setup the worker node.<br/>
The ***kubernetes join token*** should be printed upon completion of the bootstarp_master.sh script.  
<br/>

### 4. Single Node Cluser Configuration:
<br/>

***WARNING:*** *If you plan to run a single node cluster, you must enable this option below in order for the metrics-server to be enabled.*

If you want to be able to schedule Pods on the control-plane node aka master node, run the command below:

***Note: The "bootstrap_master.sh setup" script parameter option will still write/update /etc/hosts for a three node cluster.  If you did not edit the environment file to add IP Addresses for the worker node you will need to remove these redundant entries in /etc/hosts file.***

<br/>

<div id="canvas-background">

```bash
$ kubectl taint nodes --all node-role.kubernetes.io/master-
# With output looking something like:
node/k8s-master untainted
```

</div>

<br/>

This will remove the node-role.kubernetes.io/master taint from any nodes that have it, including the control-plane node, meaning that the scheduler will then be able to schedule Pods everywhere.

For more information see kubernetes documentation: [control-plane-node-isolation](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#control-plane-node-isolation)

---
---


## <h2 id="Worker_Node">Worker Node</h2>
<br/>

***Note: the below steps must be repeated on each worker node.***

### 1. Retrieve the ***kubernetes join token***:

The below command can be run to retrieve the ***kubernetes join token*** from the master node.

<br/>

<div id="canvas-background">

```Bash
$ kubeadm token create --print-join-command
# Output below...
kubeadm join 10.0.0.158:6443 --token dx98j6.freduh85iynwtx9t     --discovery-token-ca-cert-hash sha256:8445880f8e7b73a814fd468e036699e7da56505e4d61697dccf15354a387fe61
```

</div>



<br/>

### 2. Execute the [***bootstrap_worker.sh***](bootstrap_worker.sh) 

<br/>

The bootstrap_worker.sh file must be run as ***sudo*** and requires one of three parameter options:
* ***test***: dry run test for environment file
* ***setup***: first time setup of master node
* ***reset***: tear down, clean up and reset master node

Enter the ***Join Token*** when prompted. The below example is just a dry run test. In a real attempt you will use eiter ***setup or reset***.

<br/>

<div id="canvas-background">

```Bash
# This process will take several minutes to run
# Requires one of three parameters <test | setup | reset>
$ sudo ./bootstrap_worker.sh <test | setup | reset>
[sudo] password for k8s_user:
# Paste the above join token when prompted
Please enter kubeadm join token: kubeadm join 10.0.0.158:6443 --token dx98j6.freduh85iynwtx9t     --discovery-token-ca-cert-hash sha256:8445880f8e7b73a814fd468e036699e7da56505e4d61697dccf15354a387fe61

Join Token Set to: kubeadm join 10.0.0.158:6443 --token dx98j6.freduh85iynwtx9t --discovery-token-ca-cert-hash sha256:8445880f8e7b73a814fd468e036699e7da56505e4d61697dccf15354a387fe61
# This example was just a test...
Test was successful...
```

</div>


If now errors occurs, we can check the master node and verify our kubernetes cluster and connected worker nodes.

<div id="canvas-background">

```Bash
# Verify that all nodes are connected on the master node CLi
$ kubectl get nodes
# Output
NAME                 STATUS   ROLES    AGE   VERSION
k8s-master           Ready    master   10m   v1.19.2
k8s-worker-node-1    Ready    worker   2m    v1.19.2
k8s-worker-node-2    Ready    worker   1m    v1.19.2
```

</div>

<br/>

***Our kubernetes cluster is configured and ready to go now.***
<br/>

---