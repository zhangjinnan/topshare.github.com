---
layout: post
title: "有效定位和解决OpenStack问题"
description: "对OpenStack这样一个庞大的系统，遇到问题是一个比较常见的情况。当遇到问题时，如何精确的定位、分析、解决问题肯定是诸多Stacker最关心的问题，本文借鉴OpenStack社区的一些思路和自己积累的一些经验做了个总结，希望对OpenStack的用户有一定的借鉴意义。"
category: "OpenStack"
tags: [OpenStack, TroubleShooting]
---
{% include JB/setup %}

对OpenStack这样一个庞大的系统来说，遇到问题很正常，如何对遇到的问题进行精确的定位和解决才是关键？但在很多时候，从用户表象上看到的现象和后端真正的错误往往会有一些偏差。本文以OpenStack虚拟机启动工作流为基础，对OpenStack troubleshooting做一个介绍。从了解整个OpenStack中最核心的虚拟机管理，来对整个OpenStack的设计架构有个了解，为今后更复杂的问题提供一些参考。

##从启动虚拟机说起
在开始之前，如果你曾经使用过OpenStack，那请你花几分钟时间回忆一下，你所了解的虚拟机创建过程是怎么样的？如果你还没来得及安装OpenStack，那我建议你先用RDO安装一个，这样以便于让你能更好的对下面的内容进行学习。

###启动一个虚拟机需要涉及的组件

* CLI：OpenStack命令行工具，可以通过命令来创建虚拟机。
* Horizon：OpenStack图形化界面，可以更友好的通过图形化来操作虚拟机。
* Nova：OpenStack计算核心组件，调用后端的虚拟化平台API接口来最终通过镜像创建虚拟机。
* Glance：OpenStack镜像管理组件，虚拟机创建过程中需要从这个组件获取虚拟机镜像。
* Cinder：OpenStack存储管理组件，管理后端存储资源，并为虚拟机提供持久化存储的能力。
* Neutron：OpenStack网络管理组件，虚拟机创建过程中需要通过此组件获取网络信息。
* Keystone：OpenStack认证组件，虚拟机创建过程中用户和服务认证需要此服务支撑。
* MQ(RabbitMQ)：消息中间件，支持OpenStack组件内通讯。

#### Nova组件架构和通讯方式
Nova组件是整个虚拟机启动过程中最重要的组件，Nova的整个设计如下图所示：

<img src="../../../../../assets/image/nova-architecture.svg" title="nova-archtecture" width="500">

整个Nova的设计可以总结如下几点：

* Nova组件内部模块之前通讯采用AMQP
* Nova组件和其它组件之间通讯采用RESTful API
* Nova组件有本身数据库存储持久化数据

可以通过Nova的架构图回味一下Cinder、Neutron、Ceilometer的结构，会发现OpenStack设计上都有类似的地方。当了解了Nova组件内和组件间的交互形式，就可以更好的把之前说到的整个虚拟机创建过程中涉及到的所有组件串起来，下面用一个虚拟机创建的流程想想说明这个过程。

### 启动虚拟机流程
在OpenStack中，启动虚拟机整个过程看似几秒钟完成的工作，其涉及的相关知识还是相当丰富。曾近有人统计了所涉及的技术，应该在100个知识点以上，这里就不拿出来吓唬大家。重点把整个虚拟机启动过程的图就我的理解进行了整理，如下（有部分是盗用）：
<img src="../../../../../assets/image/boot_instance.png" title="boot_workflow" width="500" >

虚拟机启动过程如下：

1. 界面或命令行通过RESTful API向keystone获取认证信息。
2. keystone通过用户请求认证信息，并生成auth-token返回给对应的认证请求。
3. 界面或命令行通过RESTful API向nova-api发送一个boot instance的请求（携带auth-token）。
4. nova-api接受请求后向keystone发送认证请求，查看token是否为有效用户和token。
5. keystone验证token是否有效，如有效则返回有效的认证和对应的角色（注：有些操作需要有角色权限才能操作）。
6. 通过认证后nova-api和数据库通讯。
7. 初始化新建虚拟机的数据库记录。
8. nova-api通过rpc.call向nova-scheduler请求是否有创建虚拟机的资源(Host ID)。
9. nova-scheduler进程侦听消息队列，获取nova-api的请求。
10. nova-scheduler通过查询nova数据库中计算资源的情况，并通过调度算法计算符合虚拟机创建需要的主机。
11. 对于有符合虚拟机创建的主机，nova-scheduler更新数据库中虚拟机对应的物理主机信息。
12. nova-scheduler通过rpc.cast向nova-compute发送对应的创建虚拟机请求的消息。
13. nova-compute会从对应的消息队列中获取创建虚拟机请求的消息。
14. nova-compute通过rpc.call向nova-conductor请求获取虚拟机消息。（Flavor）
15. nova-conductor从消息队队列中拿到nova-compute请求消息。
16. nova-conductor根据消息查询虚拟机对应的信息。
17. nova-conductor从数据库中获得虚拟机对应信息。
18. nova-conductor把虚拟机信息通过消息的方式发送到消息队列中。
19. nova-compute从对应的消息队列中获取虚拟机信息消息。
20. nova-compute通过keystone的RESTfull API拿到认证的token，并通过HTTP请求glance-api获取创建虚拟机所需要镜像。
21. glance-api向keystone认证token是否有效，并返回验证结果。
22. token验证通过，nova-compute获得虚拟机镜像信息(URL)。
23. nova-compute通过keystone的RESTfull API拿到认证k的token，并通过HTTP请求neutron-server获取创建虚拟机所需要的网络信息。
24. neutron-server向keystone认证token是否有效，并返回验证结果。
25. token验证通过，nova-compute获得虚拟机网络信息。
26. nova-compute通过keystone的RESTfull API拿到认证的token，并通过HTTP请求cinder-api获取创建虚拟机所需要的持久化存储信息。
27. cinder-api向keystone认证token是否有效，并返回验证结果。
28. token验证通过，nova-compute获得虚拟机持久化存储信息。
29. nova-compute根据instance的信息调用配置的虚拟化驱动来创建虚拟机。

在虚拟机创建过程中，可以看到一个任务状态（Task），可以通过这个状态初步判断虚拟机处于哪个步骤：

* scheduling(3~12)
* networking(23~25)
* block_device_mapping(26~28)
* spawing(29)
* none（虚拟机创建成功）

记住这些状态，这个是在整个排错过程中最重要的一个状态。可以通过这个状态初步判断整个过程处于什么位置，可以很快的把问题缩小在一个比较小的范围。

##永远的日志
看到这里估计在排错的时候心里就有底气多了，不会满世界的去找问题。但还是需要提醒大家，有问题——>找日志。别看这个大家都懂的事情，往往在操作起来，大家跟愿意直接找个人问出了什么问题。大概的归类了一下OpenStack的日志：

* nova
  * /var/log/nova/*(api.log/compute.log)
* neutron
  * /var/log/neutron/*
* glance
  * /var/log/glance/*
* cinder
  * /var/log/cinder/*
* keystone
  * /var/log/keystone/*
* libvirtd
  * /var/log/libvirt/*(qemu里的日志很重要！！)

## 虚拟机涉及文件
一个虚拟机默认情况下启动过程、或者启动后会在其调度的nova-compute节点的/var/lib/nova/instances目录下会生成如下的文件：

* base目录下一个base镜像
* libvirt.xml
* disk
* disk-raw
* kernel
* ramdisk
* console.log

##辅助的工具
工具千千万只是能提升效率的一个点，关键还是在于对整个过程的理解。在OpenStack使用过程中会用到一些工具辅助排除错误，常用工具如下：

工具名称 | 工具用途 | 说明
------------ | ------------- | ------------
strace | 系统调用跟踪 | 一个简易且十分好用的系统调研跟踪工具
lsof |查看打开文件| 可以很容易的对打开的文件进行查看
tcpdump|网络抓包分析|可以通过抓发分析网络不通
kill | kill -USR1 |最近发现的牛掰用法

### strace用法
* strace -e open ping
* strace -p process_id
* strace -c ping
* strace -e trace=network nc 127.0.0.1 22

### lsof用法
* lsof -p process_id
* lsof -i :22 -n

### tcpdump用法
* tcpdump -i interface icmp（其它更多参考tcpdump命令）
* 建议配合wireshark来分析报文

### kill -USR1用法
OpenStack提供SIGUSR1用户定义的信号生成Guru Meditation报告，报告包含如下服务的完整信息和状态，这些状态会输出到标准错误输出中，可以在错误日志中查看。

{% highlight sh %}
[kevin@stack ~]$ ps -ef|grep nova-api
kevin      4320   3116 30 11:06 pts/7    00:00:03 /usr/bin/python /usr/bin/nova-api
kevin      4335   4320  2 11:06 pts/7    00:00:00 /usr/bin/python /usr/bin/nova-api
kevin      4336   4320  2 11:06 pts/7    00:00:00 /usr/bin/python /usr/bin/nova-api
kevin      4339   4320  4 11:06 pts/7    00:00:00 /usr/bin/python /usr/bin/nova-api
kevin      4340   4320  4 11:06 pts/7    00:00:00 /usr/bin/python /usr/bin/nova-api
kevin      4349   4320  9 11:06 pts/7    00:00:00 /usr/bin/python /usr/bin/nova-api
kevin      4350   4320 11 11:06 pts/7    00:00:00 /usr/bin/python /usr/bin/nova-api
kevin      4360   4205  0 11:07 pts/23   00:00:00 grep --color=auto nova-api
[kevin@stack ~]$ kill -USR1 4320
{% endhighlight %}

报告包含如下章节：

* 软件包信息
* Threads
* Green Threads
* 配置文件

{% highlight sh %}
========================================================================
====                        Guru Meditation                         ====
========================================================================
||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||


========================================================================
====                            Package                             ====
========================================================================
product = OpenStack Nova
vendor = OpenStack Foundation
version = 13.0.0
========================================================================
====                            Threads                             ====
========================================================================
------                  Thread #139957736490816                   ------

/usr/lib/python2.7/site-packages/eventlet/hubs/hub.py:346 in run
    `self.wait(sleep_time)`

/usr/lib/python2.7/site-packages/eventlet/hubs/poll.py:82 in wait
    `sleep(seconds)`

========================================================================
====                         Green Threads                          ====
========================================================================
------                        Green Thread                        ------

/usr/bin/nova-api:10 in <module>
    `sys.exit(main())`

/home/kevin/openstack/nova/nova/cmd/api.py:53 in main
    `launcher.wait()`

/usr/lib/python2.7/site-packages/oslo_service/service.py:520 in wait
    `self._respawn_children()`

/usr/lib/python2.7/site-packages/oslo_service/service.py:504 in _respawn_children
    `eventlet.greenthread.sleep(self.wait_interval)`

/usr/lib/python2.7/site-packages/eventlet/greenthread.py:34 in sleep
    `hub.switch()`

/usr/lib/python2.7/site-packages/eventlet/hubs/hub.py:294 in switch
    `return self.greenlet.switch()`

------                        Green Thread                        ------

No Traceback!

========================================================================
====                           Processes                            ====
========================================================================
Process 4320 (under 3116) [ run by: kevin (1000), state: running ]
    Process 4335 (under 4320) [ run by: kevin (1000), state: sleeping ]
    Process 4336 (under 4320) [ run by: kevin (1000), state: sleeping ]
    Process 4339 (under 4320) [ run by: kevin (1000), state: sleeping ]
    Process 4340 (under 4320) [ run by: kevin (1000), state: sleeping ]
    Process 4349 (under 4320) [ run by: kevin (1000), state: sleeping ]
    Process 4350 (under 4320) [ run by: kevin (1000), state: sleeping ]

========================================================================
====                         Configuration                          ====
========================================================================

api_database:
  connection = ***
  connection_debug = 0
  connection_trace = False
  idle_timeout = 3600
  max_overflow = None
  max_pool_size = None
  max_retries = 10
  mysql_sql_mode = TRADITIONAL
  pool_timeout = None
  retry_interval = 10
  slave_connection = ***
  sqlite_synchronous = True
……此处省略其它配置
{% endhighlight %}

##总结
OpenStack troubleshooting的过程中，最重要的是梳理OpenStack的流程。在梳理流程的基础上，配合一些工具可以解决大部分在运行过程中遇到的问题。另外一方面，由于OpenStack本身是一个云管理框架，在排错的过程当中，你往往会遇到很多KVM、存储、OVS、iptables这块的问题，对于这块的问题的解决，还是需要对其原理有一个深刻的理解才行。

###几个课后练习
* nova-api服务停止的情况下，nova-list可以列出虚拟机吗？为什么？
* 用kill命令尝试终止nova-conductor进程，会有什么报错？（提示先从日志开始）
* 用strace跟踪一下某个进程的系统调用。