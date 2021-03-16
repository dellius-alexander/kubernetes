# How To Setup NFS Server on CentOS 7 / RHEL 7
---
---
## Content:

* [Benefits of NFS](#Benefits_of_NFS)
* [Important Services](#Important_Services)
* [Important Configuration Files](#Important_Configuration_Files)
* [Environment](#Environment)
* [Configure NFS Server](#Configure_NFS_Server)
* [Configure Firewall](#Configure_Firewall)
* [Configure NFS Client](#Configure_NFS_Client)

NFS stands for Network File System, it helps you to share files and folders between Linux / Unix systems, developed by SUN Microsystems in 1990. NFS enables you to mount a remote share locally.

This guide helps you to setup NFS server on CentOS 7 / RHEL 7.

---
---
<h2 id="Benefits_of_NFS"> Benefits of NFS</h2>
<br/>

* File / Folder sharing between *nix systems
* Allows to mount remote filesystems locally 
* Can be acted as Centralized Storage system
* It can be used as a Storage Domain ( Datastore) for VMware and other Virtualization Platform.
* Allows applications to share configuration and data files with multiple nodes.
* Allows having updated files across the share.

---
---
<h2 id="Important_Services">Important Services</h2>
<br/>
The following are the important NFS services, included in nfs-utils packages.

* **rpcbind**: The rpcbind utility is a server that converts RPC program numbers into universal addresses. It must be running on the host to be able to make RPC calls on a server on that machine.
* **nfs-server**: It enables clients to access NFS shares.
* **nfs-lock / rpc-statd**: NFS file locking. Implement file lock recovery when an NFS server crashes and reboots.
* **nfs-idmap**: It translates user and group ids into names, and to translate user and group names
into ids

---
---
<h2 id="Important_Configuration_Files">Important Configuration Files</h2>
<br/>

You would be working mainly on below configuration files to setup NFS server and Clients.
* [**/etc/exports**](http://nfs.sourceforge.net/nfs-howto/ar01s03.html#106): contains a table of local physical file systems on an NFS server that are accessible to NFS clients. It is the main configuration file, that controls which file systems are exported to remote hosts and specifies options. Check the man pages ([man exports](http://nfs.sourceforge.net/nfs-howto/ar01s03.html#106)) for a complete description of all the setup options for the file.
* **/etc/fstab**: This file is used to control what file systems including NFS directories are mounted when the system boots.
* **/etc/sysconfig/nfs**: This file is used to control which ports the required RPC services run on.
* **/etc/hosts.allow** and **/etc/hosts.deny**: These files are called TCP wrappers, controls the access to the NFS server. It is used by NFS to decide whether or not to accept a connection coming in from another IP address.

---
---
<h2 id="Environment">Environment</h2>
<br/>

Here, we will use CentOS 7 minimal for this demo. This guide should also work on Oracle Linux and Fedora systems. This assumes that the Server and Client are on the same network/subnet.  You will have to configure your reverse proxy for the below Server/Client Host Name and IP address.

* NFS Server:<br/>
  - Host Name: server.example.local (CentOS 7) <br/>
  IP Address: 10.0.0.10/24

* NFS Client:<br/>
  - Host Name: client.example.local (CentOS 7) <br/>
  IP Address: 10.0.0.20/28

---
---
<h2 id="Configure_NFS_Server">Configure NFS Server</h2>
<br/>

Install NFS Server <br/>
Install the below package for NFS server and firewall configuration tool using the yum command.
<br/>
<br/>

```Bash
# Install on both Server & Client
$ yum install -y nfs-utils firewalld
```

Once the packages are installed, enable and start NFS services.
<br/>
<br/>

```Bash
# Do only on Server, Not client machine
$ systemctl start nfs-server rpcbind
$ systemctl enable nfs-server rpcbind
```

### Create NFS Share Directory:
<br/>

Now, let’s create a directory to share with the NFS client. Here we will be creating a new directory named ***nfsfileshare*** in the / partition or root partition.

You can also share your existing directory with NFS.
<br/>
<br/>

```Bash
# Create a directory to share with the NFS Client
$ mkdir /nfsfileshare
# Allow NFS client to read and write to the created directory.
$ chmod 777 /nfsfileshare/
```

### Add NFS Share Direcotry to /etc/exports:<br/>

We have to modify /etc/exports file to make an entry of directory /nfsfileshare that you want to share. [Click here for a list of options](http://nfs.sourceforge.net/nfs-howto/ar01s03.html#106), or type [**man exports**](https://linux.die.net/man/5/exports) for the man pages at CLi. 

* /etc/exports Options:
    - ***ro***: The directory is shared read only; the client machine will not be able to write it. This is the default.
    - ***rw***: The client machine will have read and write access to the directory.
    - ***no_root_squash***: By default, any file request made by user root on the client machine is treated as if it is made by user nobody on the server. (Exactly which UID the request is mapped to depends on the UID of user "nobody" on the server, not the client.) If no_root_squash is selected, then root on the client machine will have the same level of access to the files on the system as root on the server. This can have serious security implications, although it may be necessary if you want to perform any administrative work on the client machine that involves the exported directories. You should not specify this option without a good reason.
    - ***no_subtree_check***: If only part of a volume is exported, a routine called subtree checking verifies that a file that is requested from the client is in the appropriate part of the volume. If the entire volume is exported, disabling this check will speed up transfers.
    - ***sync***: By default, all but the most recent version (version 1.11) of the exportfs command will use async behavior, telling a client machine that a file write is complete - that is, has been written to stable storage - when NFS has finished handing the write over to the filesystem. This behavior may cause data corruption if the server reboots, and the sync option prevents this. See [Optimizing NFS Performance](http://nfs.sourceforge.net/nfs-howto/ar01s05.html) for a complete discussion of sync and async behavior.
    - You can get to know all the option in the man page [**man exports**](https://linux.die.net/man/5/exports) or [**Click Here**](https://linux.die.net/man/5/exports).


* Format of ***/etc/exports*** entry:
    - \<Absolute Path of NFS Directory>  \<machine_1 IP Address>/CIDR(option1,option2,more_options,...), \<machine_2 IP Address>(option1,option2, more_options,...)

* /nfsfileshare: shared directory

    ***Note***: /nfsfileshare is an arbitrary name used for the purpose of this guide. It is recommended that you use a meaningful name for your NFS share directory. The machines may be listed by their DNS address or their IP address (e.g., machine.company.com or 10.0.0.15/255.255.255.240). Using IP addresses is more reliable and more secure. Using the IP Address & Subnet Mask pair restricts access to a specific block of hosts within that Subnet block. In this case the client address requesting access must be in the range of addresses all inclusive of 10.0.0.15 - 10.0.0.29, to gain access to the remote NFS directory.*
* 10.0.0.20: is the IP address of client machine. We can also use the hostname instead of an IP address. It is also possible to define the range of clients with subnet like: ***10.0.0.15/28***, which was used in the above example.
<br/>
<br/>

```Bash
# Change User to root.
# You may need to enter password to access root account.
$ sudo -i
# Add the NFS directory to /etc/exports with options in order to persist reboots.
# In this example we used the host address range between 10.0.0.15 - 10.0.0.29 with CIDR /28
$ cat >> /etc/exports <<EOF
/nfsfileshare  10.0.0.15/28(rw,sync,no_root_squash)
EOF
# Exit root User
$ exit
```

### OR 
<br/>

```Bash
# Manually enter NFS directory into /etc/exports using built-in text editor.
# Change User to root.
# You may need to enter password to access root account.
$ sudo -i
# Add the NFS directory to /etc/exports with options in order to persist reboots.
# In this example we used a single host address
$ vi /etc/exports
/nfsfileshare  10.0.0.20(rw,sync,no_root_squash)
~
~
"/etc/exports" 0L, 0C
# Enter [SHIFT][:][q] to exit vi edit mode and save changes
# Exit root User
$ exit
```

Export the shared directories using the following command:
<br/>
<br/>

```Bash
$ exportfs -r
```

### Extras:
<br/>
* exportfs -v: Displays a list of shares files and export options on a server.
* exportfs -a: Exports all directories listed in /etc/exports.
* exportfs -u: UnExport one or more directories.
* exportfs -r: ReExport all directories after modifying /etc/exports.

After configuring NFS server, we need to mount that shared directory in the NFS client.

### Check NFS Share:
<br/>
Before mounting the NFS share, we need to check the NFS shares available on the NFS server by running the following command on the NFS client. Replace the IP Address with your NFS server IP Address or hostname.
<br/>
<br/>

```Bash
$ showmount -e 10.0.0.10
# Output
Export list for 10.0.0.10:
/nfsfileshare 10.0.0.20
```
As per the output, the /nfsfileshare is available on the NFS server (10.0.0.10) for the NFS client (10.0.0.20).

### Extras:

* showmount -e : Shows the available shares on your local machine (NFS Server).
* showmount -e <server-ip or hostname>: Lists the available shares on the remote server

---
---
<h2 id="Configure_Firewall">Configure Firewall</h2>
<br/>
We need to configure the firewall on the NFS server to allow NFS client to access the NFS share. To do that, run the following commands on the NFS server.
<br/>
<br/>

```Bash
$ firewall-cmd --permanent --add-service mountd
$ firewall-cmd --permanent --add-service rpc-bind
$ firewall-cmd --permanent --add-service nfs
$ firewall-cmd --reload
```

---
---
<h2 id="Configure_NFS_Client">Configure NFS Client</h2><br/>

### Install NFS package on Client machine:
<br/>
We need to install NFS packages on NFS client to mount a remote NFS share. Install NFS packages using below command.
<br/>
<br/>

```Bash
$ yum install -y nfs-utils
```

### Create NFS Share Directory on Client machine:
<br/>
Now, create a directory on the NFS client to mount the NFS share directory /nfsfileshare which we have created on the NFS server.
<br/>
<br/>

```Bash
$ mkdir -p /mnt/nfsfileshare
```

### Mount NFS Share on Client machine:
<br/>

Use the below command to mount the NFS share directory ***/nfsfileshare*** from NFS server 10.0.0.10 to ***/mnt/nfsfileshare*** on NFS client.

* Command format:
    - mount  \<IP Address>:/share/directory/on/server  /share/directory/on/client
<br/>
<br/>

```Bash
$ mount 10.0.0.10:/nfsfileshare /mnt/nfsfileshare
# Verify the mounted share on the NFS client using mount command.
$ mount | grep nfs
# Output
sunrpc on /var/lib/nfs/rpc_pipefs type rpc_pipefs (rw,relatime)
nfsd on /proc/fs/nfsd type nfsd (rw,relatime)
10.0.0.10:/nfsfileshare on /mnt/nfsfileshare type nfs4 (rw,relatime,vers=4.1,rsize=131072,wsize=131072,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,clientaddr=10.0.0.20,local_lock=none,addr=10.0.0.10)
```

Also, you can use the df -hT command to check the mounted NFS share.
<br/>
<br/>

```Bash
$ df -hT
# Output
Filesystem                 Type      Size  Used Avail Use% Mounted on
/dev/mapper/centos-root    xfs        50G  1.2G   49G   3% /
devtmpfs                   devtmpfs  485M     0  485M   0% /dev
tmpfs                      tmpfs     496M     0  496M   0% /dev/shm
tmpfs                      tmpfs     496M  6.7M  490M   2% /run
tmpfs                      tmpfs     496M     0  496M   0% /sys/fs/cgroup
/dev/mapper/centos-home    xfs        47G   33M   47G   1% /home
/dev/sda1                  xfs      1014M  154M  861M  16% /boot
tmpfs                      tmpfs     100M     0  100M   0% /run/user/0
10.0.0.10:/nfsfileshare nfs4       50G  1.2G   49G   3% /mnt/nfsfileshare
```

Create a file on the mounted directory to verify the read and write access on NFS share.
<br/>
<br/>

```Bash
# Create a new file in mounted directory
$ cat >> /mnt/nfsfileshare/test.txt <<EOF
This is a test file...
EOF
# Verify that file exists
$ cat /mnt/nfsfileshare/test.txt
This is a test file...
```

If the above command returns no error, you have working NFS setup.

### Automount NFS Shares:
<br/>

To mount the shares automatically on every reboot, you would need to modify /etc/fstab file of your NFS client. [Click here for the complete list of fstab file configuration](https://man7.org/linux/man-pages/man5/fstab.5.html) or type ***man fstab*** at the CLi.

Format of /etc/fstab file configuration: 
* \<Device> \<Mount Point> \<File System Type> \<Options> \<Dump> \<Pass>

    - ***Device*** – the first field specifies the mount device. These are usually device filenames. Most distributions now specify partitions by their labels or UUIDs.
    - ***Mount point*** – the second field specifies the mount point, the directory where the partition or disk will be mounted. This should usually be an empty directory in another file system.
    - ***File system type*** – the third field specifies the file system type.
    - ***Options*** – the fourth field specifies the mount options. Most file systems support several mount options, which modify how the kernel treats the file system. You may specify multiple mount options, separated by commas.
    - ***Backup operation/Dump*** – the fifth field contains a 1 if the dump utility should back up a partition or a 0 if it shouldn’t. If you never use the dump backup program, you can ignore this option.
    - ***File system check order/Pass*** – the sixth field specifies the order in which fsck checks the device/partition for errors at boot time. A 0 means that fsck should not check a file system. Higher numbers represent the check order. The root partition should have a value of 1 , and all others that need to be checked should have a value of 2.
<br/>
<br/>

```Bash
# Change User to root.
# You may need to enter password to access root account.
$ sudo -i
# Add the NFS share to /etc/fstab
$ vi /etc/fstab
# Add an entry something like below.
# /etc/fstab
# Created by anaconda on Wed Jan 17 12:04:02 2018
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=60a496d0-69f4-4355-aef0-c31d688dda1b /boot                   xfs     defaults        0 0
/dev/mapper/centos-home /home                   xfs     defaults        0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
10.0.0.10:/nfsfileshare /mnt/nfsfileshare    nfs     nosuid,rw,sync,hard,intr  0  0
```
Save and close the file.<br/>
Reboot the client machine and check whether the share is automatically mounted or not.
<br/>
<br/>

```Bash
$ reboot -h 0
```

Verify the mounted share on the NFS client using mount command.
<br/>
<br/>

```Bash
$ mount | grep nfs
# Output
sunrpc on /var/lib/nfs/rpc_pipefs type rpc_pipefs (rw,relatime)
10.0.0.10:/nfsfileshare on /mnt/nfsfileshare type nfs4 (rw,nosuid,relatime,sync,vers=4.1,rsize=131072,wsize=131072,namlen=255,hard,proto=tcp,port=0,timeo=600,retrans=2,sec=sys,clientaddr=10.0.0.20,local_lock=none,addr=10.0.0.10)
```

### OR

You can use the df -hT command to check the mounted NFS share.
<br/>
<br/>

```Bash
$ df -hT
# Output
Filesystem                 Type      Size  Used Avail Use% Mounted on
/dev/mapper/centos-root    xfs        50G  1.2G   49G   3% /
devtmpfs                   devtmpfs  485M     0  485M   0% /dev
tmpfs                      tmpfs     496M     0  496M   0% /dev/shm
tmpfs                      tmpfs     496M  6.7M  490M   2% /run
tmpfs                      tmpfs     496M     0  496M   0% /sys/fs/cgroup
/dev/mapper/centos-home    xfs        47G   33M   47G   1% /home
/dev/sda1                  xfs      1014M  154M  861M  16% /boot
tmpfs                      tmpfs     100M     0  100M   0% /run/user/0
10.0.0.10:/nfsfileshare nfs4       50G  1.2G   49G   3% /mnt/nfsfileshare
```

If you want to unmount that shared directory from your NFS client after you are done with the file sharing, you can unmount that particular directory using umount command.
<br/>
<br/>

```Bash
$ umount /mnt/nfsfileshare
```

---
---
## References:
[Linux NFS-HOWTO](http://nfs.sourceforge.net/nfs-howto/index.html)