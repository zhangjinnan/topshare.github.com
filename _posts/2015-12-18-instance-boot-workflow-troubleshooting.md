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
在开始之前，如果你曾经使用过OpenStack，那请你花几分钟时间回忆一下，你所了解的虚拟机创建过程。如果你还没来得及安装OpenStack，那我建议你先安装一个，这样以便于让你能更好的对下面的内容进行学习。

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

cells:
  bandwidth_update_interval = 600
  call_timeout = 60
  capabilities =
    hypervisor=xenserver;kvm
    os=linux;windows
  cell_type = compute
  enable = False
  instance_update_sync_database_limit = 100
  manager = nova.cells.manager.CellsManager
  mute_child_interval = 300
  name = nova
  reserve_percent = 10.0
  topic = cells

cinder:
  cafile = None
  catalog_info = volumev2:cinderv2:publicURL
  certfile = None
  cross_az_attach = True
  endpoint_template = None
  http_retries = 3
  insecure = False
  keyfile = None
  os_region_name = RegionOne
  timeout = None

conductor:
  manager = nova.conductor.manager.ConductorManager
  topic = conductor
  use_local = False
  workers = 2

database:
  backend = sqlalchemy
  connection = ***
  connection_debug = 0
  connection_trace = False
  db_inc_retry_interval = True
  db_max_retries = 20
  db_max_retry_interval = 10
  db_retry_interval = 1
  idle_timeout = 3600
  max_overflow = None
  max_pool_size = None
  max_retries = 10
  min_pool_size = 1
  mysql_sql_mode = TRADITIONAL
  pool_timeout = None
  retry_interval = 10
  slave_connection = ***
  sqlite_db = nova.sqlite
  sqlite_synchronous = True
  use_db_reconnect = False
  use_tpool = False

default:
  aggregate_image_properties_isolation_namespace = None
  aggregate_image_properties_isolation_separator = .
  allow_instance_snapshots = True
  allow_resize_to_same_host = True
  allow_same_net_traffic = True
  api_paste_config = /etc/nova/api-paste.ini
  api_rate_limit = False
  auth_strategy = keystone
  auto_assign_floating_ip = False
  bandwidth_poll_interval = 600
  baremetal_scheduler_default_filters =
    AvailabilityZoneFilter
    ComputeCapabilitiesFilter
    ComputeFilter
    ExactCoreFilter
    ExactDiskFilter
    ExactRamFilter
    ImagePropertiesFilter
    RetryFilter
  bindir = /usr/bin
  block_device_allocate_retries = 60
  block_device_allocate_retries_interval = 3
  boot_script_template = /home/kevin/openstack/nova/nova/cloudpipe/bootscript.template
  ca_file = cacert.pem
  ca_path = /home/kevin/data/nova/CA
  cert_manager = nova.cert.manager.CertManager
  cert_topic = cert
  client_socket_timeout = 900
  cnt_vpn_clients = 0
  compute_available_monitors = None
  compute_driver = libvirt.LibvirtDriver
  compute_manager = nova.compute.manager.ComputeManager
  compute_monitors =
  compute_resources =
  compute_stats_class = nova.compute.stats.Stats
  compute_topic = compute
  config-dir = None
  config-file =
    /etc/nova/nova.conf
  config_drive_format = iso9660
  config_drive_skip_versions = 1.0 2007-01-19 2007-03-01 2007-08-29 2007-10-10 2007-12-15 2008-02-01 2008-09-01
  console_host = stack
  console_manager = nova.console.manager.ConsoleProxyManager
  console_topic = console
  consoleauth_manager = nova.consoleauth.manager.ConsoleAuthManager
  consoleauth_topic = consoleauth
  control_exchange = nova
  cpu_allocation_ratio = 0.0
  create_unique_mac_address_attempts = 5
  crl_file = crl.pem
  db_driver = nova.db
  debug = True
  default_access_ip_network_name = None
  default_availability_zone = nova
  default_ephemeral_format = ext4
  default_flavor = m1.small
  default_floating_pool = public
  default_log_levels =
    amqp=WARN
    amqplib=WARN
    boto=WARN
    glanceclient=WARN
    iso8601=WARN
    keystonemiddleware=WARN
    oslo_messaging=INFO
    qpid=WARN
    requests.packages.urllib3.connectionpool=WARN
    routes.middleware=WARN
    sqlalchemy=WARN
    stevedore=WARN
    suds=INFO
    urllib3.connectionpool=WARN
    websocket=WARN
  default_notification_level = INFO
  default_publisher_id = None
  default_schedule_zone = None
  defer_iptables_apply = False
  dhcp_domain = novalocal
  dhcp_lease_time = 86400
  dhcpbridge = /usr/bin/nova-dhcpbridge
  dhcpbridge_flagfile =
    /etc/nova/nova.conf
  disk_allocation_ratio = 1.0
  dmz_cidr =
  dmz_mask = 255.255.255.0
  dmz_net = 10.0.0.0
  dns_server =
  dns_update_periodic_interval = -1
  dnsmasq_config_file =
  ebtables_exec_attempts = 3
  ebtables_retry_interval = 1.0
  ec2_dmz_host = 192.168.234.12
  ec2_host = 192.168.234.12
  ec2_listen = 0.0.0.0
  ec2_listen_port = 8773
  ec2_path = /
  ec2_port = 8773
  ec2_private_dns_show_ip = False
  ec2_scheme = http
  ec2_strict_validation = True
  ec2_timestamp_expiry = 300
  ec2_workers = 2
  enable_instance_password = True
  enable_network_quota = False
  enable_new_services = True
  enabled_apis =
    ec2
    metadata
    osapi_compute
  enabled_ssl_apis =
  fake_call = False
  fake_network = False
  fatal_deprecations = False
  fatal_exception_format_errors = False
  firewall_driver = nova.virt.firewall.NoopFirewallDriver
  fixed_ip_disassociate_timeout = 600
  fixed_range_v6 = fd00::/48
  flat_injected = False
  flat_interface = None
  flat_network_bridge = None
  flat_network_dns = 8.8.4.4
  floating_ip_dns_manager = nova.network.noop_dns_driver.NoopDNSDriver
  force_config_drive = True
  force_dhcp_release = True
  force_raw_images = True
  force_snat_range =
  forward_bridge_interface =
    all
  fping_path = /usr/sbin/fping
  gateway = None
  gateway_v6 = None
  graceful_shutdown_timeout = 5
  heal_instance_info_cache_interval = 60
  host = stack
  image_cache_manager_interval = 2400
  image_cache_subdirectory_name = _base
  image_decryption_dir = /tmp
  injected_network_template = /home/kevin/openstack/nova/nova/virt/interfaces.template
  instance_build_timeout = 0
  instance_delete_interval = 300
  instance_dns_domain =
  instance_dns_manager = nova.network.noop_dns_driver.NoopDNSDriver
  instance_format = [instance: %(uuid)s]
  instance_name_template = instance-%08x
  instance_usage_audit = False
  instance_usage_audit_period = month
  instance_uuid_format = [instance: %(uuid)s]
  instances_path = /home/kevin/data/nova/instances
  internal_service_availability_zone = internal
  io_ops_weight_multiplier = -1.0
  iptables_bottom_regex =
  iptables_drop_action = DROP
  iptables_top_regex =
  ipv6_backend = rfc2462
  isolated_hosts =
  isolated_images =
  key_file = private/cakey.pem
  keys_path = /home/kevin/data/nova/keys
  keystone_ec2_insecure = False
  keystone_ec2_url = http://192.168.234.12:5000/v2.0/ec2tokens
  l3_lib = nova.network.l3.LinuxNetL3
  linuxnet_interface_driver = nova.network.linux_net.LinuxBridgeInterfaceDriver
  linuxnet_ovs_integration_bridge = br-int
  live_migration_retry_count = 30
  lockout_attempts = 5
  lockout_minutes = 15
  lockout_window = 15
  log-config-append = None
  log-date-format = %Y-%m-%d %H:%M:%S
  log-dir = None
  log-file = None
  log-format = None
  log_options = True
  logging_context_format_string = %(asctime)s.%(msecs)03d %(color)s%(levelname)s %(name)s [%(request_id)s %(user_name)s %(project_name)s%(color)s] %(instance)s%(color)s%(message)s
  logging_debug_format_suffix = from (pid=%(process)d) %(funcName)s %(pathname)s:%(lineno)d
  logging_default_format_string = %(asctime)s.%(msecs)03d %(color)s%(levelname)s %(name)s [-%(color)s] %(instance)s%(color)s%(message)s
  logging_exception_prefix = %(color)s%(asctime)s.%(msecs)03d TRACE %(name)s %(instance)s
  logging_user_identity_format = %(user)s %(tenant)s %(domain)s %(user_domain)s %(project_domain)s
  max_age = 0
  max_concurrent_builds = 10
  max_concurrent_live_migrations = 1
  max_header_line = 16384
  max_instances_per_host = 50
  max_io_ops_per_host = 8
  max_local_block_devices = 3
  maximum_instance_delete_attempts = 5
  memcached_servers = None
  metadata_cache_expiration = 15
  metadata_host = 192.168.234.12
  metadata_listen = 0.0.0.0
  metadata_listen_port = 8775
  metadata_manager = nova.api.manager.MetadataManager
  metadata_port = 8775
  metadata_workers = 2
  migrate_max_retries = -1
  mkisofs_cmd = genisoimage
  monkey_patch = False
  monkey_patch_modules =
    nova.api.ec2.cloud:nova.notifications.notify_decorator
    nova.compute.api:nova.notifications.notify_decorator
  multi_host = False
  multi_instance_display_name_template = %(name)s-%(count)d
  my_block_storage_ip = 192.168.234.12
  my_ip = 192.168.234.12
  network_allocate_retries = 0
  network_api_class = nova.network.neutronv2.api.API
  network_device_mtu = None
  network_driver = nova.network.linux_net
  network_manager = nova.network.manager.VlanManager
  network_size = 256
  network_topic = network
  networks_path = /home/kevin/data/nova/networks
  neutron_default_tenant_id = default
  non_inheritable_image_properties =
    bittorrent
    cache_in_nova
  notification_driver =
  notification_topics =
    notifications
  notification_transport_url = None
  notify_api_faults = False
  notify_on_state_change = None
  null_kernel = nokernel
  num_networks = 1
  osapi_compute_ext_list =
  osapi_compute_extension =
    nova.api.openstack.compute.legacy_v2.contrib.standard_extensions
  osapi_compute_link_prefix = None
  osapi_compute_listen = 0.0.0.0
  osapi_compute_listen_port = 8774
  osapi_compute_unique_server_name_scope =
  osapi_compute_workers = 2
  osapi_glance_link_prefix = None
  osapi_hide_server_address_states =
    building
  osapi_max_limit = 1000
  ovs_vsctl_timeout = 120
  password_length = 12
  pci_alias =
  pci_passthrough_whitelist =
  periodic_enable = True
  periodic_fuzzy_delay = 60
  preallocate_images = none
  project_cert_subject = /C=US/ST=California/O=OpenStack/OU=NovaDev/CN=project-ca-%.16s-%s
  public_interface = eth0
  publish_errors = False
  pybasedir = /home/kevin/openstack/nova
  quota_cores = 20
  quota_driver = nova.quota.DbQuotaDriver
  quota_fixed_ips = -1
  quota_floating_ips = 10
  quota_injected_file_content_bytes = 10240
  quota_injected_file_path_length = 255
  quota_injected_files = 5
  quota_instances = 10
  quota_key_pairs = 100
  quota_metadata_items = 128
  quota_networks = 3
  quota_ram = 51200
  quota_security_group_rules = 20
  quota_security_groups = 10
  quota_server_group_members = 10
  quota_server_groups = 10
  ram_allocation_ratio = 0.0
  ram_weight_multiplier = 1.0
  reboot_timeout = 0
  reclaim_instance_interval = 0
  region_list =
  remove_unused_base_images = True
  remove_unused_original_minimum_age_seconds = 86400
  report_interval = 10
  rescue_timeout = 0
  reservation_expire = 86400
  reserved_host_disk_mb = 0
  reserved_host_memory_mb = 512
  resize_confirm_window = 0
  resize_fs_using_block_device = False
  restrict_isolated_hosts_to_isolated_images = True
  resume_guests_state_on_host_boot = False
  rootwrap_config = /etc/nova/rootwrap.conf
  routing_source_ip = 192.168.234.12
  rpc_backend = rabbit
  rpc_response_timeout = 60
  run_external_periodic_tasks = True
  running_deleted_instance_action = reap
  running_deleted_instance_poll_interval = 1800
  running_deleted_instance_timeout = 0
  s3_access_key = notchecked
  s3_affix_tenant = False
  s3_host = 192.168.234.12
  s3_port = 3333
  s3_secret_key = notchecked
  s3_use_ssl = False
  scheduler_available_filters =
    nova.scheduler.filters.all_filters
  scheduler_default_filters =
    AvailabilityZoneFilter
    ComputeCapabilitiesFilter
    ComputeFilter
    DiskFilter
    ImagePropertiesFilter
    RamFilter
    RetryFilter
    ServerGroupAffinityFilter
    ServerGroupAntiAffinityFilter
  scheduler_driver = nova.scheduler.filter_scheduler.FilterScheduler
  scheduler_driver_task_period = 60
  scheduler_host_manager = nova.scheduler.host_manager.HostManager
  scheduler_host_subset_size = 1
  scheduler_instance_sync_interval = 120
  scheduler_json_config_location =
  scheduler_manager = nova.scheduler.manager.SchedulerManager
  scheduler_max_attempts = 3
  scheduler_topic = scheduler
  scheduler_tracks_instance_changes = True
  scheduler_use_baremetal_filters = False
  scheduler_weight_classes =
    nova.scheduler.weights.all_weighers
  secure_proxy_ssl_header = None
  security_group_api = neutron
  send_arp_for_ha = False
  send_arp_for_ha_count = 3
  service_down_time = 60
  servicegroup_driver = db
  share_dhcp_address = False
  shelved_offload_time = 0
  shelved_poll_interval = 3600
  shutdown_timeout = 60
  snapshot_name_template = snapshot-%s
  ssl_ca_file = None
  ssl_cert_file = None
  ssl_key_file = None
  state_path = /home/kevin/data/nova
  sync_power_state_interval = 600
  syslog-log-facility = LOG_USER
  tcp_keepidle = 600
  teardown_unused_network_gateway = False
  tempdir = None
  transport_url = None
  until_refresh = 0
  update_dns_entries = False
  update_resources_interval = 0
  use-syslog = False
  use-syslog-rfc-format = True
  use_cow_images = True
  use_forwarded_for = False
  use_ipv6 = False
  use_network_dns_servers = False
  use_neutron_default_nets = False
  use_project_ca = False
  use_rootwrap_daemon = False
  use_single_default_gateway = False
  use_stderr = True
  user_cert_subject = /C=US/ST=California/O=OpenStack/OU=NovaDev/CN=%.16s-%.16s-%s
  vcpu_pin_set = None
  vendordata_driver = nova.api.metadata.vendordata_json.JsonFileVendorData
  verbose = True
  vif_plugging_is_fatal = True
  vif_plugging_timeout = 300
  virt_mkfs =
  vlan_interface = None
  vlan_start = 100
  volume_api_class = nova.volume.cinder.API
  volume_usage_poll_interval = 0
  vpn_flavor = m1.tiny
  vpn_image_id = 0
  vpn_ip = 192.168.234.12
  vpn_key_suffix = -vpn
  vpn_start = 1000
  watch-log-file = False
  wsgi_default_pool_size = 1000
  wsgi_keep_alive = True
  wsgi_log_format = %(client_ip)s "%(request_line)s" status: %(status_code)s len: %(body_length)s time: %(wall_seconds).7f

ephemeral_storage_encryption:
  cipher = aes-xts-plain64
  enabled = False
  key_size = 512

glance:
  allowed_direct_url_schemes =
  api_insecure = False
  api_servers =
    http://192.168.234.12:9292
  host = 192.168.234.12
  num_retries = 0
  port = 9292
  protocol = http

guestfs:
  debug = False

image_file_url:
  filesystems =

ironic:
  admin_auth_token = ***
  admin_password = ***
  admin_tenant_name = None
  admin_url = None
  admin_username = None
  api_endpoint = None
  api_max_retries = 60
  api_retry_interval = 2
  api_version = 1
  client_log_level = None

keymgr:
  api_class = nova.keymgr.conf_key_mgr.ConfKeyManager

keystone_authtoken:
  admin_password = ***
  admin_tenant_name = admin
  admin_token = ***
  admin_user = None
  auth-url = http://192.168.234.12:35357
  auth_admin_prefix =
  auth_host = 127.0.0.1
  auth_port = 35357
  auth_protocol = https
  auth_section = None
  auth_type = password
  auth_uri = http://192.168.234.12:5000
  auth_version = None
  cache = None
  cafile = /home/kevin/data/ca-bundle.pem
  certfile = None
  check_revocations_for_cached = False
  default-domain-id = None
  default-domain-name = None
  delay_auth_decision = False
  domain-id = None
  domain-name = None
  enforce_token_bind = permissive
  hash_algorithms =
    md5
  http_connect_timeout = None
  http_request_max_retries = 3
  identity_uri = None
  include_service_catalog = True
  insecure = False
  keyfile = None
  memcache_pool_conn_get_timeout = 10
  memcache_pool_dead_retry = 300
  memcache_pool_maxsize = 10
  memcache_pool_socket_timeout = 3
  memcache_pool_unused_timeout = 60
  memcache_secret_key = ***
  memcache_security_strategy = None
  memcache_use_advanced_pool = False
  memcached_servers = None
  password = admin
  project-domain-id = default
  project-domain-name = None
  project-id = None
  project-name = service
  region_name = None
  revocation_cache_time = 10
  signing_dir = /var/cache/nova
  token_cache_time = 300
  trust-id = None
  user-domain-id = default
  user-domain-name = None
  user-id = None
  user-name = nova

libvirt:
  block_migration_flag = VIR_MIGRATE_UNDEFINE_SOURCE, VIR_MIGRATE_PEER2PEER, VIR_MIGRATE_LIVE, VIR_MIGRATE_TUNNELLED, VIR_MIGRATE_NON_SHARED_INC
  checksum_base_images = False
  checksum_interval_seconds = 3600
  connection_uri =
  cpu_mode = none
  cpu_model = None
  disk_cachemodes =
  disk_prefix = None
  gid_maps =
  hw_disk_discard = None
  hw_machine_type = None
  image_info_filename_pattern = /home/kevin/data/nova/instances/_base/%(image)s.info
  images_rbd_ceph_conf =
  images_rbd_pool = rbd
  images_type = default
  images_volume_group = None
  inject_key = False
  inject_partition = -2
  inject_password = False
  iscsi_iface = None
  iscsi_use_multipath = False
  live_migration_bandwidth = 0
  live_migration_completion_timeout = 800
  live_migration_downtime = 500
  live_migration_downtime_delay = 75
  live_migration_downtime_steps = 10
  live_migration_flag = VIR_MIGRATE_UNDEFINE_SOURCE, VIR_MIGRATE_PEER2PEER, VIR_MIGRATE_LIVE, VIR_MIGRATE_TUNNELLED
  live_migration_progress_timeout = 150
  live_migration_uri = qemu+ssh://kevin@%s/system
  mem_stats_period_seconds = 10
  num_iscsi_scan_tries = 5
  qemu_allowed_storage_drivers =
  rbd_secret_uuid = None
  rbd_user = None
  remote_filesystem_transport = ssh
  remove_unused_kernels = True
  remove_unused_resized_minimum_age_seconds = 3600
  rescue_image_id = None
  rescue_kernel_id = None
  rescue_ramdisk_id = None
  rng_dev_path = None
  snapshot_compression = False
  snapshot_image_format = None
  snapshots_directory = /home/kevin/data/nova/instances/snapshots
  sparse_logical_volumes = False
  sysinfo_serial = auto
  uid_maps =
  use_usb_tablet = False
  use_virtio_for_bridges = True
  virt_type = kvm
  volume_clear = zero
  volume_clear_size = 0
  wait_soft_reboot_seconds = 120
  xen_hvmloader_path = /usr/lib/xen/boot/hvmloader

metrics:
  required = True
  weight_multiplier = 1.0
  weight_of_unavailable = -10000.0
  weight_setting =

mks:
  enabled = False
  mksproxy_base_url = http://127.0.0.1:6090/

neutron:
  auth_plugin = v3password
  auth_section = None
  cafile = None
  certfile = None
  extension_sync_interval = 600
  insecure = False
  keyfile = None
  metadata_proxy_shared_secret = ***
  ovs_bridge = br-int
  region_name = RegionOne
  service_metadata_proxy = True
  timeout = None
  url = http://192.168.234.12:9696

osapi_v21:
  enabled = True
  extensions_blacklist =
  extensions_whitelist =

oslo_concurrency:
  disable_process_locking = False
  lock_path = /home/kevin/data/nova

oslo_messaging_rabbit:
  amqp_auto_delete = False
  amqp_durable_queues = False
  fake_rabbit = False
  heartbeat_rate = 2
  heartbeat_timeout_threshold = 60
  kombu_reconnect_delay = 1.0
  kombu_reconnect_timeout = 60
  kombu_ssl_ca_certs =
  kombu_ssl_certfile =
  kombu_ssl_keyfile =
  kombu_ssl_version =
  rabbit_ha_queues = False
  rabbit_host = localhost
  rabbit_hosts =
    192.168.234.12
  rabbit_login_method = AMQPLAIN
  rabbit_max_retries = 0
  rabbit_password = ***
  rabbit_port = 5672
  rabbit_retry_backoff = 2
  rabbit_retry_interval = 1
  rabbit_use_ssl = False
  rabbit_userid = stackrabbit
  rabbit_virtual_host = /
  rpc_conn_pool_size = 30
  send_single_reply = False

oslo_middleware:
  max_request_body_size = 114688

oslo_reports:
  log_dir = None

oslo_versionedobjects:
  fatal_exception_format_errors = False

rdp:
  enabled = False
  html5_proxy_base_url = http://127.0.0.1:6083/

remote_debug:
  host = None
  port = None

serial_console:
  base_url = ws://127.0.0.1:6083/
  enabled = False
  listen = 127.0.0.1
  port_range = 10000:20000
  proxyclient_address = 127.0.0.1
  serialproxy_host = 0.0.0.0
  serialproxy_port = 6083

spice:
  agent_enabled = True
  enabled = False
  html5proxy_base_url = http://192.168.234.12:6082/spice_auto.html
  keymap = en-us
  server_listen = 127.0.0.1
  server_proxyclient_address = 127.0.0.1

ssl:
  ca_file = None
  cert_file = None
  ciphers = None
  key_file = None
  version = None

trusted_computing:
  attestation_api_url = /OpenAttestationWebServices/V1.0
  attestation_auth_blob = None
  attestation_auth_timeout = 60
  attestation_insecure_ssl = False
  attestation_port = 8443
  attestation_server = None
  attestation_server_ca_file = None

upgrade_levels:
  baseapi = None
  cells = None
  cert = None
  compute = None
  conductor = None
  console = None
  consoleauth = None
  network = None
  scheduler = None

vnc:
  enabled = True
  keymap = en-us
  novncproxy_base_url = http://192.168.234.12:6080/vnc_auto.html
  vncserver_listen = 127.0.0.1
  vncserver_proxyclient_address = 127.0.0.1
  xvpvncproxy_base_url = http://192.168.234.12:6081/console

workarounds:
  destroy_after_evacuate = True
  disable_libvirt_livesnapshot = True
  disable_rootwrap = False
  handle_virt_lifecycle_events = True
{% endhighlight %}

##总结
OpenStack troubleshooting的过程中，最重要的是梳理OpenStack的流程。在梳理流程的基础上，配合一些工具可以解决大部分在运行过程中遇到的问题。另外一方面，由于OpenStack本身是一个云管理框架，在排错的过程当中，你往往会遇到很多KVM、存储、OVS、iptables这块的问题，对于这块的问题的解决，还是需要对其原理有一个深刻的理解才行。

###几个课后练习
* nova-api服务停止的情况下，nova-list可以列出虚拟机吗？为什么？
* 用kill命令尝试终止nova-conductor进程，会有什么报错？（提示先从日志开始）
* 用strace跟踪一下某个进程的系统调用。