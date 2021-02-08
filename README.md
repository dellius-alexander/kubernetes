# Kubernetes Installation

---
# Contents:

* [On Master Node](#Master_Node)
* [On Worker Node](#Worker_Node)

### Kubernetes Configuration bootstraps:
   - One Master Node
   - Two Worker Nodes
   
You can optionally add an NFS share server to your Cluster.  [Click Here for More Details](NFS_README.md)
    
### See [Kubernetes Command Reference](https://github.com/dellius-alexander/k8s-yaml-template/blob/master/k8s-commands/cheatsheet.md) for a list of commands
---

***Note: Kubernetes setup for Bare Metal configuration of minimal CentOS 7 / RHEL 7 machines.***

---
---

# <h2 id="Master_Node">On Master</h2>

<hr/>

## 1. Clone Repo:

<br/>

<div id="canvas-background">

```Bash
# Clone the repo...
$ git clone https://github.com/dellius-alexander/kubernetes.git
$ cd kubernetes
# Rename k8s.env.example file to k8s.env and update as needed...
$ mv k8s.env.example k8s.env
```

</div>

## 1.2. Edit hosts.conf file:

<br/>

The `hosts.conf` file defines the hosts/nodes configuration of your cluster.  List all nodes in your cluster here as kubernetes will reference these nodes after they are joined to this cluster. This configuration file will replace the `/etc/hosts` file on each node.  Update the `k8s.env` file for as many nodes as you like as well as `hosts.conf`  file to match each unique variable `"e.g. __WORKER_NODE_#__"` as needed..

<div id="canvas-background">

```bash
127.0.0.1 localhost
::1 localhost
${__MASTER_NODE__} k8s-master.example.com k8s-master
${__WORKER_NODE_1__} k8s-worker-node-1.example.com k8s-worker-node-1
${__WORKER_NODE_2__} k8s-worker-node-2.example.com k8s-worker-node-2
```

</div>




<br/>
<hr/>

## 2. Edit the [***k8s.env***](k8s.env.example) file required configuration options:

Add or remove node definitions as needed here to correspond with your `hosts.conf` file.

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
__APISERVER_ADVERTISE_ADDRESS__=<Enter IP Address of __MASTER_NODE__>   # EDIT
__CNI_MTU__=1500
__CALICO_DISABLE_FILE_LOGGING__=info
__CALICO_IPV4POOL_CIDR__=/16
__CALICO_IPV4POOL_IPIP__=Always
__CALICO_IPV4POOL_VXLAN__=Never
__CALICO_NETWORKING_BACKEND__=bird
__DATASTORE_TYPE__=kubernetes
__K8S_API_ROOT__=http://<Enter IP Address of __MASTER_NODE__>:6443    # EDIT 
__KUBECONFIG__=/<Directory of kubeconfig file>/.kube/config    # EDIT 
__KUBECONFIG_FILEPATH__=/etc/kubernetes/admin.conf
__KUBECONFIG_DIRECTORY__=/<Directory of kubeconfig file>/.kube    # EDIT 
__KUBERNETES_NODE_NAME__=k8s-master
__KUBERNETES_SERVICE_HOST__=<Enter IP Address>    # EDIT 
__KUBERNETES_SERVICE_PORT__=6443
__NODENAME__=k8s-master
__POD_NETWORK_CIDR__=192.168.0.0/16
__USER__=<Enter system user info aka $USER>    # EDIT 
__USER_HOME__=<Enter system user home directory>    # EDIT 
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
<hr/>

## 3. Docker Daemon Configuration

<div id="canvas-background">
<br/>

You need to install a container runtime on each node in the cluster so that Pods can run there. We will be using `Docker` as the [Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) for our kubernetes cluster. Docker also offers configuration options for your container runtime.

There are two ways to configure the Docker daemon:

* Use a JSON configuration file. This is the preferred option, since it keeps all configurations in a single place and persists restarts.
* Use flags when starting `dockerd`.

You can use both of these options together as long as you don’t specify the same option both as a flag and in the JSON file. If that happens, the Docker daemon won’t start and prints an error message.

To configure the Docker daemon using a JSON file, create a file at `/etc/docker/daemon.json` on Linux systems, or `C:\ProgramData\docker\config\daemon.json` on Windows. On MacOS go to the whale in the taskbar > Preferences > Daemon > Advanced.

### On Linux

The default location of the configuration file on Linux is /etc/docker/daemon.json. The --config-file flag can be used to specify a non-default location.

See [Daemon Configuration file](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-configuration-file) for full list of configuration options. This implementation will employ the below docker daemon configuration options.

***Note: You can modify the `daemon.json` configuration file, to add or edit docker daemon configuration options.***

For more details read: [Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)

<br/>

```json
// Daemon configuration file
{
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
      "max-size": "250m"
    },
    "storage-driver": "overlay2",
    "storage-opts": [
      "overlay2.override_kernel_check=true"
    ],
    "selinux-enabled": false
  }

```

<hr/>

</div>

## 4. Execute the [***bootstrap_master.sh***](bootstrap_master.sh) script:
<br/>

The bootstrap_master.sh file must be run as ***sudo*** and requires one of three parameter options:
* ***test***: dry run test for environment file.
* ***setup***: first time setup of master node.
* ***reset***: tear down, clean up and setup master node again.
* ***stop***: tear down and clean up node; returning the node back to original state.

<br/>

<div id="canvas-background">

```Bash
# This process will take several minutes to run
# Requires one of three parameters <test | setup | reset>
$ sudo ./bootstrap_master.sh <test | setup | reset | stop>
[sudo] password for k8s_user:
```

</div>



If no errors occurs, we will need the ***kubernetes join token***  to setup the worker node.<br/>
The ***kubernetes join token*** should be printed upon completion of the bootstarp_master.sh script.  
<br/>
<hr/>

## 5. Single Node Cluser Configuration:
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


# <h2 id="Worker_Node">Worker Node</h2>
<br/>

***Note: the below steps must be repeated on each worker node.***

## 1. Retrieve the ***kubernetes join token***:

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

## 2. Execute the [***bootstrap_worker.sh***](bootstrap_worker.sh) 

<br/>

The bootstrap_worker.sh file must be run as ***sudo*** and requires one of three parameter options:
* ***test***: dry run test for environment file.
* ***setup***: first time setup of master node.
* ***reset***: tear down, clean up and reset master node.
* ***stop***: tear down and clean up node; returning the node back to original state.

Enter the ***Join Token*** when prompted. The below example is just a dry run test. In a real attempt you will use eiter ***setup or reset***.

<br/>

<div id="canvas-background">

```Bash
# This process will take several minutes to run
# Requires one of three parameters <test | setup | reset>
$ sudo ./bootstrap_worker.sh <test | setup | reset | stop>
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

## 3. Install bash-completion 

The kubectl completion script for Bash can be generated with the command `kubectl completion bash`. Sourcing the completion script in your shell enables kubectl autocompletion.

However, the completion script depends on [bash-completion](https://github.com/scop/bash-completion#installation), which means that you have to install this software first (you can test if you have bash-completion already installed by running type `_init_completion`).

Bash-completion is provided by many package managers (see [here](https://github.com/scop/bash-completion#installation)). You can install it with `apt-get install bash-completion` or `yum install bash-completion`, etc.

The above commands create /usr/share/bash-completion/bash_completion, which is the main script of bash-completion. Depending on your package manager, you have to manually source this file in your `~/.bashrc` file.

To find out, reload your shell and run type _init_completion. If the command succeeds, you're already set, otherwise add the following to your ~/.bashrc file:
```bash
source /usr/share/bash-completion/bash_completion
```


Reload your shell and verify that bash-completion is correctly installed by typing type `_init_completion`.

## Enable kubectl autocompletion:

You now need to ensure that the kubectl completion script gets sourced in all your shell sessions. There are two ways in which you can do this:

Source the completion script in your `~/.bashrc` file:

```bash
echo 'source <(kubectl completion bash)' >>~/.bashrc
```

Add the completion script to the /etc/bash_completion.d directory:

```bash
kubectl completion bash >/etc/bash_completion.d/kubectl
  ```

If you have an alias for kubectl, you can extend shell completion to work with that alias:
```bash
echo 'alias k=kubectl' >>~/.bashrc
echo 'complete -F __start_kubectl k' >>~/.bashrc
```

Note: bash-completion sources all completion scripts in /etc/bash_completion.d.