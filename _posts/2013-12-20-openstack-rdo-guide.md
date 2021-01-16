---
layout: post
title: "OpenStack RDO guide"
description: "基于Redhat的RDO版本的安装，其实手工安装也不是很麻烦。初学者可以试着先RPM一个个装一下，有利于入门。"
category: "OpenStack"
tags: [OpenStack install, RDO]
---
{% include JB/setup %}
# OpenStack RDO
## install use packstack
安装就简单给大家介绍了，不做深入分析，详情请友情参考沙克同学的博客。

	[root@RDO-Test ~]# yum -y install openstack-packstack
	[root@RDO-Test ~]# packstack --gen-answer-file=rdo-test.txt
	[root@RDO-Test ~]#packstack --answer-file my_answers.txt
	


## 用RDO的RPM包手动安装
安装完centos6.5 min导入OpenStack的yum源，update系统
	
	[root@k-compute01 ~]# yum install -y http://rdo.fedorapeople.org/rdo-release.rpm
	[root@k-compute01 ~]# yum update

### 安装mysql
	[root@k-controller01 ~]# yum install mysql-server
	启动mysql服务：
	[root@k-controller01 ~]# /etc/init.d/mysqld start
	修改root密码：
	[root@k-controller01 ~]# /usr/bin/mysqladmin -u root password '99cloud'
	[root@k-controller01 ~]# chkconfig mysqld on
	[root@controller ~]# chkconfig mysqld on



### 安装RabbitMQ
	[root@controller ~]# yum install rabbitmq-server
	[root@controller ~]# service rabbitmq-server start
	Starting rabbitmq-server: SUCCESS
	rabbitmq-server.
	[root@controller ~]# chkconfig rabbitmq-server on



### 安装keystone
#### 准备工作
创建keystone数据库，并赋予权限：

	mysql> create database keystone;
	Query OK, 1 row affected (0.00 sec)

	mysql> grant all privileges on keystone.* to 'keystone'@'%' identified by 'keystone';
	Query OK, 0 rows affected (0.00 sec)
	mysql> grant all privileges on keystone.* to 'keystone'@'localhost' identified by 'keystone';
	Query OK, 0 rows affected (0.00 sec)

在redhat中，如果不加localhost这条授权，你用mysql client本地去连接的时候总是报错，比较奇怪，如果有知道原因的还请指教。
#### 安装keystone软件包
	[root@controller ~]# yum -y install openstack-keystone

#### 配置keystone
在配置前需要导入keystone的环境变量，如下的方式导入
	
	export OS_SERVICE_TOKEN=99cloud
	export OS_SERVICE_ENDPOINT=http://10.5.0.10:35357/v2.0

	

#### 启动服务
初始化数据库：

	[root@controller keystone]# keystone-manage db_sync

启动服务：
	
	[root@controller keystone]# /etc/init.d/memcached restart
	Stopping memcached:                                        [FAILED]
	Starting memcached:                                        [  OK  ]
	[root@controller keystone]# chkconfig memcached on
	[root@controller keystone]# service openstack-keystone start
	[root@controller keystone]# chkconfig openstack-keystone on
	

#### 初始化数据


### glance安装
#### 准备工作
准备glance的数据库，并给予相应用户访问权限：

	mysql> create database glance;
	Query OK, 1 row affected (0.00 sec)

	mysql> grant all privileges on glance.* to 'glance'@'%' identified by 'glance';
	Query OK, 0 rows affected (0.00 sec)

	mysql> grant all privileges on glance.* to 'glance'@'localhost' identified by 'glance';
	Query OK, 0 rows affected (0.00 sec)


#### 安装glance软件包
	[root@controller ~]# yum install -y install openstack-glance


### 配置glance



### 重启服务

	[root@controller ~]# /etc/init.d/openstack-glance-api restart
	Stopping openstack-glance-api:                             [FAILED]
	Starting openstack-glance-api:                             [  OK  ]
	[root@controller ~]# chkconfig openstack-glance-api on
	[root@controller ~]# /etc/init.d/openstack-glance-api status
	openstack-glance-api (pid  15900) is running...
	
	[root@controller glance]# service openstack-glance-registry start
	Starting openstack-glance-registry:                        [  OK  ]
	[root@controller glance]# chkconfig openstack-glance-registry on


### 上传一个测试镜像
	glance image-create --name=testimg --container-format=bare --disk-format=qcow2 --is-public=true < install.log






## Neutron安装（VLAN模式）

	mysql> create database neutron;
	Query OK, 1 row affected (0.00 sec)

	mysql> grant all privileges on neutron.* to 'neutron'@'%' identified by 'neutron';
	Query OK, 0 rows affected (0.01 sec)

	mysql> grant all privileges on neutron.* to 'neutron'@'localhost' identified by 'neutron';
	Query OK, 0 rows affected (0.00 sec)





    [root@controller ~]# keystone user-create --name=neutron --pass=neutron --email=neutron@trystack.cn
    +----------+----------------------------------+
    | Property |              Value               |
    +----------+----------------------------------+
    |  email   |       neutron@trystack.cn        |
    | enabled  |               True               |
    |    id    | 64f230d377ea43cb92acdd153b02ccc5 |
    |   name   |             neutron              |
    +----------+----------------------------------+
    [root@controller ~]# keystone user-role-add  --user=neutron --tenant=service --role=admin
    [root@controller ~]# keystone service-create --name=neutron --type=network \
    >      --description="OpenStack Networking Service"
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    | description |   OpenStack Networking Service   |
    |      id     | 8872f121e61a4fe085de414d6233679f |
    |     name    |             neutron              |
    |     type    |             network              |
    +-------------+----------------------------------+
    [root@controller ~]# keystone endpoint-create \
    > --service-id 8872f121e61a4fe085de414d6233679f \
    > --publicurl=http://10.5.0.10:9696 \
    > --internalurl=http://10.5.0.10:9696 \
    > --adminurl=http://10.5.0.10:9696
    +-------------+----------------------------------+
    |   Property  |              Value               |
    +-------------+----------------------------------+
    |   adminurl  |      http://10.5.0.10:9696       |
    |      id     | 653d04912d0746f39e6e06f97ae23576 |
    | internalurl |      http://10.5.0.10:9696       |
    |  publicurl  |      http://10.5.0.10:9696       |
    |    region   |            regionOne             |
    |  service_id | 8872f121e61a4fe085de414d6233679f |
    +-------------+----------------------------------+




`/etc/sysctl.conf`

	net.ipv4.ip_forward=1
	net.ipv4.conf.all.rp_filter=0
	net.ipv4.conf.default.rp_filter=0

 执行sysctl -p是内核参数生效：
	
	[root@controller neutron]# sysctl -p



	service openvswitch start
	chkconfig openvswitch on
	
	ovs-vsctl add-br br-int
	

## RDO中的一些问题
### RPM包下载
如果你用过RDO，其实你会发现一个问题，有时候就是一直失败，结果你重新执行packstack安装，又发现没有问题了。这个问题其实在安装RDO里面还是一个比较常见的问题，特别是你在安装多节点的时候。造成这个问题的原因估计大家都懂的，一部分原因是我们生活在天朝。那么如何解决这个问题，如果你把RDO相关的RPM包做成本地源，那这个问题出现的几率就要小很多。

有如下的几种方式来解决这个问题：

**yumdownloader下载**

使用yumdownloader根据自己需要的RPM包一个个下载（当然用脚本做这个事情相对比较容易），再做成本地仓库。
	
	[root@RDO-Test ~]# yum -y install yum-utils
    [root@RDO-Test ~]# yumdownloader --destdir=/root/rdoPackage/ --resolve XXX
这样做的话你需要拿到你要安装RPM包的一个列表，这样你就可以很精确的把需要的软件包和其依赖包都下载下来，如果你需要做自己修改RDO的东西，并自己用，这个是个不错的方式。

**安装一遍，再取软件包**

这个相对来说对于不知道如何拿安装包的兄弟们来说是一个不错的选择，可以比较快的通过这种方式可以获得相对比较全的数据包，对于直接用RDO的朋友还是不错的选择。对于这种方式，相对来说也比较容易，只需要配置`/etc/yum.conf`:

	[main]
	cachedir=/root/rdoPackage
	keepcache=1
配置如上的参数即可，主要是你需要RPM的cache存放的目录和是否需要cache，默认yum是不cache RPM包的。


#### rpm list
本list是CentOS min安装完成后，采用update更新后所需要的主RPM包，可以采用yumdownloader下载软件包和其依赖包：
    
    
    
    
### RDO手动安装OpenStack报错
在采用RDO安装OpenStack的时候，导入RDO的源后，安装出现如下错误：

	--> Finished Dependency Resolution
	Error: Package: 1:python-oslo-config-1.2.1-1.el6.noarch (openstack-havana)
           Requires: python-six
	Error: Package: python-warlock-1.0.1-1.el6.noarch (openstack-havana)
           Requires: python-jsonschema
**问题原因**

由于CentOS RDO源还缺少EPEL的源，导致有些python的依赖包无法找到。

**解决方法**

添加CentOS的EPEL源：

	[epel]
	name=Extra Packages for Enterprise Linux 6 - $basearch
	#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch
	mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch
	failovermethod=priority
	enabled=1
	gpgcheck=1
	gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6

	[epel-debuginfo]
	name=Extra Packages for Enterprise Linux 6 - $basearch - Debug
	#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch/debug
	mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-	debug-6&arch=$basearch
	failovermethod=priority
	enabled=0
	gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
	gpgcheck=1

	[epel-source]
	name=Extra Packages for Enterprise Linux 6 - $basearch - Source
	#baseurl=http://download.fedoraproject.org/pub/epel/6/SRPMS
	mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-source-6&arch=$basearch
	failovermethod=priority
	enabled=0
	gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-6
	gpgcheck=1



### 挂载镜像
采用nbd挂载，需要加载nbd模块：

	root@stack-X9DR3-F:~# grep NBD /boot/config-3.2.0-54-generic
	CONFIG_BLK_DEV_NBD=m
	root@stack-X9DR3-F:~# modinfo nbd
	filename:       /lib/modules/3.2.0-54-generic/kernel/drivers/block/nbd.ko
	license:        GPL
	description:    Network Block Device
	srcversion:     826AF3132F77B4AFE91D437
	depends:
	intree:         Y
	vermagic:       3.2.0-54-generic SMP mod_unload modversions
	parm:           nbds_max:number of network block devices to initialize (default: 16) (int)
	parm:           max_part:number of partitions per device (default: 0) (int)
	parm:           debugflags:flags for controlling debug output (int)

加载nbd模块，并制定最多的nbd设备数：

	root@stack-X9DR3-F:~# modprobe nbd max_part=16
	root@stack-X9DR3-F:~# lsmod |grep nbd
	nbd                    17744  0
	root@stack-X9DR3-F:~# ls -l /dev/nbd
	nbd0   nbd1   nbd10  nbd11  nbd12  nbd13  nbd14  nbd15  nbd2   nbd3   nbd4   nbd5   nbd6   nbd7   nbd8   nbd9
	
连接nbd设备，注意需要全路径：

	root@stack-X9DR3-F:~# qemu-nbd -c /dev/nbd0 /home/stack/ubuntu-12.04-server-cloudimg-i386-disk1.img

查看镜像磁盘分区情况，并挂载：

	root@stack-X9DR3-F:~# fdisk -l /dev/nbd0

	Disk /dev/nbd0: 2147 MB, 2147483648 bytes
	4 heads, 32 sectors/track, 32768 cylinders, total 4194304 sectors
	Units = sectors of 1 * 512 = 512 bytes
	Sector size (logical/physical): 512 bytes / 512 bytes
	I/O size (minimum/optimal): 512 bytes / 512 bytes
	Disk identifier: 0x000426dc

     Device Boot      Start         End      Blocks   Id  System
	/dev/nbd0p1   *        2048     4194303     2096128   83  Linux
	
	root@stack-X9DR3-F:~# mount /dev/nbd0p1 /mnt/

卸载nbd设备：

	root@stack-X9DR3-F:~# qemu-nbd -d /dev/nbd0
	/dev/nbd0 disconnected


修改密码：

	root@stack-X9DR3-F:/mnt/etc# chroot /mnt/
	bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
	root@stack-X9DR3-F:/# id ubuntu
	uid=1000(ubuntu) gid=1000(ubuntu) groups=1000(ubuntu),4(adm),20(dialout),24(cdrom),25(floppy),29(audio),30(dip),44(video),46(plugdev),110(netdev),111(admin)
	root@stack-X9DR3-F:/# passwd ubuntu
	Enter new UNIX password:
	Retype new UNIX password:
	passwd: password updated successfully
