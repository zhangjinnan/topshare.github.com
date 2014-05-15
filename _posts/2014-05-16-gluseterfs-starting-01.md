---
layout: post
title: "GLusterFS测试之入门"
description: "今天花了点时间安装了一下GlusterFS，顺道简单的测试了一下GlusterFS的一些性能，并给出了一些自己的分析，如有不对的地方请GlusterFS大神指点。感谢weibo几个GlusterFS砖家拿砖头砸我的服务器，以便测试GlusterFS的高可用性。"
category: "storage"
tags: [GlusterFS, Storage, Testing]
---
{% include JB/setup %}
今天花了点时间安装了一下GlusterFS，顺道简单的测试了一下GlusterFS的一些性能，并给出了一些自己的分析，如有不对的地方请GlusterFS大神指点。感谢weibo几个GlusterFS砖家拿砖头砸我的服务器，以便测试GlusterFS的高可用性。目前测试下来，主要瓶颈在于GlusterFS Client网络带宽瓶颈。

##测试环境情况
目前测试节点有7个，其中一个作为性能测试的客户端。仅需安装GlusterFS Client软件，并任意挂载其中一个GlusterFS存储节点。

7台服务器配置如下，其中网络为1Gb、下面磁盘都为两块磁盘的raid 1，详细的配置如下：

|CPU  | 内存 | 硬盘 |
|-----|------|------|
|E5504|16G   |300G  |
|E5520|16G   |300G  |
|E5520|32G   |300G  |
|E5620|32G   |300G  |
|E5620|32G   |600G  |
|E5620|32G   |1T    |
|E5620|32G   |1T    |

##GlusterFS安装
GlusterFS安装才CentOS 6.4操作系统，直接采用EPEL源和GLusterFS官方源最新版本(3.5.0)。
###EPEL源和GlusterFS源
增加EPEL源和GLusterFS源，EPEL源中包含GLusterFS，版本比较旧，相对稳定，本次测试采用最新的3.5.0版本。
{% highlight sh %}
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
wget -P /etc/yum.repos.d http://download.gluster.org/pub/gluster/glusterfs/LATEST/CentOS/glusterfs-epel.repo
{% endhighlight %}

###yum安装GlusterFS

安装GlusterFS Server端
{% highlight sh %}
yum -y install glusterfs glusterfs-fuse glusterfs-server
{% endhighlight %}

安装GlusterFS Client端
{% highlight sh %}
yum -y install glusterfs glusterfs-fuse
{% endhighlight %}

###初始化Brick
对于GlusterFS节点，每个划分一个100G的分区用做GlusterFS的Brick设备，并挂载到/glusterfs/disk1目录下$。`注意:`需要在格式化100G的分区为ext4，挂载结束后在每个/glusterfs/disk1目录下创建data目录用于Brick的目录。测试节点挂载情况如下：
{% highlight sh %}
/dev/sda5 on /glusterfs/disk1 type ext4 (rw)
/dev/sda4 on /glusterfs/disk1 type ext4 (rw)
/dev/sda5 on /glusterfs/disk1 type ext4 (rw)
/dev/sda5 on /glusterfs/disk1 type ext4 (rw)
/dev/sda4 on /glusterfs/disk1 type ext4 (rw)
/dev/sda5 on /glusterfs/disk1 type ext4 (rw)
{% endhighlight %}



###创建GlusterFS测试卷
本次测试简单模拟大文件写入，需要对写入数据有副本，创建一个两个副本的分片的GlusterFS卷，其中卷类型设置时，Stripe为3，replica为2。
{% highlight sh %}
gluster> volume create rep2-stripe3 stripe 3 replica 2 transport tcp  trystack-node-2:/glusterfs/disk1/data trystack-node-3:/glusterfs/disk1/data trystack-node-4:/glusterfs/disk1/data trystack-node-5:/glusterfs/disk1/data trystack-node-6:/glusterfs/disk1/data trystack-node-7:/glusterfs/disk1/data
{% endhighlight %}
	
	
###查看卷状态
{% highlight sh %}
gluster> volume status
Volume rep2-stripe3 is not started
{% endhighlight %}
可以看到rep2-stripe3卷处于停止状态，可以采用volume start启动卷。

###启动卷
{% highlight sh %}
gluster> volume start rep2-stripe3
volume start: rep2-stripe3: success
{% endhighlight %}

###启动后查看卷状态
{% highlight sh %}
gluster> volume status
Status of volume: rep2-stripe3
Gluster process						Port	Online	Pid
------------------------------------------------------------------------------
Brick trystack-node-2:/glusterfs/disk1/data		49152	Y	1770
Brick trystack-node-3:/glusterfs/disk1/data		49152	Y	1741
Brick trystack-node-4:/glusterfs/disk1/data		49152	Y	1691
Brick trystack-node-5:/glusterfs/disk1/data		49152	Y	1679
Brick trystack-node-6:/glusterfs/disk1/data		49152	Y	1805
Brick trystack-node-7:/glusterfs/disk1/data		49152	Y	1806
NFS Server on localhost					2049	Y	1784
Self-heal Daemon on localhost				N/A	Y	1788
NFS Server on trystack-node-3				2049	Y	1754
Self-heal Daemon on trystack-node-3			N/A	Y	1759
NFS Server on trystack-node-5				2049	Y	1693
Self-heal Daemon on trystack-node-5			N/A	Y	1697
NFS Server on trystack-node-7				2049	Y	1820
Self-heal Daemon on trystack-node-7			N/A	Y	1824
NFS Server on trystack-node-6				2049	Y	1817
Self-heal Daemon on trystack-node-6			N/A	Y	1824
NFS Server on trystack-node-4				2049	Y	1705
Self-heal Daemon on trystack-node-4			N/A	Y	1709

Task Status of Volume rep2-stripe3
------------------------------------------------------------------------------
There are no active volume tasks
{% endhighlight %}


###客户端挂载
{% highlight sh %}
[root@trystack-node-1 kevin]# mount -t glusterfs trystack-node-2:/rep2-stripe3 /mnt/
{% endhighlight %}


##测试

###测试GlusterFS客户端到Server端的网络性能
从测试数据来看，GLusterFS挂载客户端1Gb网络Bandwidth大概在941Mb/s，基本上已经到千兆网络的上限水平。
{% highlight sh %}
[root@trystack-node-2 ~]# iperf -s
------------------------------------------------------------
Server listening on TCP port 5001
TCP window size: 85.3 KByte (default)
------------------------------------------------------------
[  4] local 10.240.216.12 port 5001 connected with 10.240.216.11 port 45264
[ ID] Interval       Transfer     Bandwidth
[  4]  0.0-10.0 sec  1.10 GBytes   941 Mbits/sec
{% endhighlight %}

###采用dd简单测试顺序写入性能
简单测试一个顺序写入GLusterFS的性能，这里采用8k的顺序写入到客户端。
{% highlight sh %}
[root@trystack-node-1 ~]# time dd if=/dev/zero of=/mnt/bigfile2 bs=8k count=102400
{% endhighlight %}

##glances监控
为了便于对所有测试节点进行监控和数据分析，这里采用Linux上比较直观可以查看命令glances对Linux各种资源做一个简单的监控。在CentOS上安装glances仅需`yum -y install glances`即可。

##测试结果分析
对于测试结果，先上一张图，在慢慢分析：
<img src="../../../../../assets/image/glusterfs_test1.png" title="GlusterFS测试" width="500" >
简单的介绍一下图分布，最左的两个图分别为客户端的监控和dd测试的图，从图中可以给出如下的结论:

* 网络是整个系统的瓶颈
* replica 2时，GlusterFS Client端直接写两份给整个存储系统，当replica份数越多，client写入性能越低(942/8/2=58.875MB/s)
* 文件根据stripe均分在各个GlusterFS节点
* 写入是各个Server基本均分

目前可遇见或已知的几点：

* 千兆网络GlusterFS性能网络很容易成瓶颈
* GlusterFS和NFS Client挂载方式处理机制不同(NFS不会直接写两份，写完由后端写两份，weibo上一个达人告知的)
* 换10Gb网络测试性能还有提升
* 在未把存储节点的网络带宽跑满的情况下，增加Client端还能榨干存储性能

问题：

* SSD如何提升存储性能
* VM镜像采用何种模式存储(stripe or not stripe)
* 后端如何选择使用磁盘(raid or 裸盘)
* GlusterFS如何做Cache合理
* GlusterFS到底消耗多少CPU和内存资源
* GlusterFS和OpenStack结合后功能如何

##结束语
对GlusterFS算先入个门，期间也感谢几个玩GlusterFS的朋友的指点。当然，还有很多的问题需要去一步步的去探究。当然，如果有幸圈子里面的朋友看到了，也请多多指点，您的指点是对我最大的帮助，谢谢！
