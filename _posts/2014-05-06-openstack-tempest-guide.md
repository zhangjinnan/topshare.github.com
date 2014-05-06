---
layout: post
title: "OpenStack Tempest入门介绍"
description: "主要简单介绍一些OpenStack Tempest项目的一些情况，并根据自己的理解给出一个测试的案例。为OpenStack后续的功能性测试和性能测试做铺垫。"
category: "OpenStack"
tags: [OpenStack, Testing]
---
{% include JB/setup %}
#OpenStack Tempest
Tempest是一个OpenStack自动化测试的项目，主要用来测试OpenStack API进行测试和一部分的压力测试，包含了一部分的CLI client的测试和场景测试。简单的看了一下Tempest的代码构成，主要测试方式还是类似于单元测试的写法，目前看到主要用了nose来驱动测试。

##Tempest安装
从github克隆tempest源码：
{% highlight sh %}
git clone https://github.com/openstack/tempest.git
{% endhighlight %}
	
安装python-pip，需要增加EPEL源：
{% highlight sh %}
yum install python-pip
{% endhighlight %}

安装依赖：
{% highlight sh %}
[root@dev tempest]# python tools/install_venv.py
{% endhighlight %}

或者手工安装依赖：
{% highlight sh %}
[root@dev tempest]# virtualenv .venv
[root@dev tempest]# source .venv/bin/activate
(.venv)[root@dev tempest]# pip install -r requirements.txt
{% endhighlight %}


`注意`安装依赖包cryptography失败，centos安装需要毅力如下包：
{% highlight sh %}
[root@dev tempest]# yum install gcc libffi-devel python-devel openssl-devel
{% endhighlight %}


测试工具采用nose或者testr，建议安装：
{% highlight sh %}
(.venv)[root@dev tempest]# pip install nose
(.venv)[root@dev tempest]# pip install unittest
{% endhighlight %}
	
至此安装结束，可以通过这块测试一些基本用例。

##Tempest代码结构

{% highlight sh %}
(.venv)[root@dev tempest]# tree -d -L 1
.
├── api
├── api_schema
├── cli
├── cmd
├── common
├── hacking
├── openstack
├── scenario
├── services
├── stress
├── test_discover
├── tests
└── thirdparty
{% endhighlight %}

测试的主要模块有如下几部分，`api`主要测试OpenStack API部分的功能，`cli`主要测试OpenStack CLI接口，`scenario`主要根据一些复杂场景进行测试，`stress`压力测试部分，目前可以结合rally进行压力测试，`thirdparty`这部分主要针对于EC2的API测试用例。

##测试配置（以测试token为例说明）
修改tempest测试配置文件:
{% highlight sh %}
(.venv)[root@dev tempest]# cp etc/tempest.conf.sample etc/tempest.conf
{% endhighlight %}

{% highlight sh %}
(.venv)[root@dev tempest]# more etc/tempest.conf|grep ^[^#]
[DEFAULT]
[baremetal]
[boto]
[cli]
[compute]
image_ref=7e3d9740-0f0c-4b05-89c3-7cb0ca39fcfe
image_ref_alt=7e3d9740-0f0c-4b05-89c3-7cb0ca39fcfe
[compute-admin]
[compute-feature-enabled]
[dashboard]
[data_processing]
[database]
[debug]
[identity]
catalog_type=identity
uri=http://192.168.1.170:35357/v2.0
uri_v3=192.168.1.170
auth_version=v2
region=RegionOne
endpoint_type=publicURL
username=nova
tenant_name=service
password=nova
admin_username=admin
admin_tenant_name=admin
admin_password=admin
[identity-feature-enabled]
[image]
[image-feature-enabled]
[input-scenario]
[negative]
[network]
[network-feature-enabled]
[object-storage]
[object-storage-feature-enabled]
[orchestration]
[queuing]
[scenario]
[service_available]
[stress]
[telemetry]
[volume]
[volume-feature-enabled]
{% endhighlight %}

注意，本次测试主要针对于token这块的测试，仅做说明使用，这里仅需配置[compute][indentifty]两个配置项，如需要测试其它需要根据需要配置其它参数。

##测试
这里作为入门选择一个api的测试作为例子进行测试，其它的测试方式雷同，以后做测试可以进行参考。这里选择测试keystone的token相关的功能，具体测试过程如下：

{% highlight sh %}
[root@dev admin]# pwd
/root/code/tempest/tempest/api/identity/admin
[root@dev admin]# source /root/code/tempest/.venv/bin/activate
(.venv)[root@dev admin]# nosetests test_tokens.py
2014-05-06 07:16:54.704 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_create_get_delete_token): 200 POST http://192.168.1.170:35357/v2.0/tenants 0.106s
2014-05-06 07:16:54.989 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_create_get_delete_token): 200 POST http://192.168.1.170:35357/v2.0/users 0.281s
2014-05-06 07:16:55.526 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_create_get_delete_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
2014-05-06 07:16:55.555 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_create_get_delete_token): 200 GET http://192.168.1.170:35357/v2.0/tokens/65dbd2d8f75349a0befd49ac9c1b0335 0.025s
2014-05-06 07:16:55.655 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_create_get_delete_token): 204 DELETE http://192.168.1.170:35357/v2.0/tokens/65dbd2d8f75349a0befd49ac9c1b0335 0.097s
.2014-05-06 07:16:55.839 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/users 0.176s
2014-05-06 07:16:55.939 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tenants 0.097s
2014-05-06 07:16:56.023 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tenants 0.082s
2014-05-06 07:16:56.115 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/OS-KSADM/roles 0.089s
2014-05-06 07:16:56.260 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 PUT http://192.168.1.170:35357/v2.0/tenants/62e72aed4ccc40048ed50c1a9cf291cb/users/b119894011b74a9c8c8564b0a743bb0f/roles/OS-KSADM/e2a02994ed32460d9de624344faaad83 0.144s
2014-05-06 07:16:56.363 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 PUT http://192.168.1.170:35357/v2.0/tenants/090c1306c0a143769219e8184846e66c/users/b119894011b74a9c8c8564b0a743bb0f/roles/OS-KSADM/e2a02994ed32460d9de624344faaad83 0.100s
2014-05-06 07:16:56.544 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
2014-05-06 07:16:56.677 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
2014-05-06 07:16:56.871 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 204 DELETE http://192.168.1.170:35357/v2.0/tokens/8aabad1359be48398a93c9493d986ef7 0.190s
2014-05-06 07:16:57.167 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
.2014-05-06 07:16:57.573 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/users/93b695fc2a6241f0b8d36b09753cbade 0.396s
2014-05-06 07:16:58.392 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/users/b119894011b74a9c8c8564b0a743bb0f 0.817s
2014-05-06 07:16:58.505 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/tenants/61b052f86490446e930a76f524d5b84e 0.111s
2014-05-06 07:16:58.651 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/tenants/62e72aed4ccc40048ed50c1a9cf291cb 0.144s
2014-05-06 07:16:58.764 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/tenants/090c1306c0a143769219e8184846e66c 0.112s
2014-05-06 07:16:58.879 9543 INFO tempest.common.rest_client [-] Request (TokensTestJSON:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/OS-KSADM/roles/e2a02994ed32460d9de624344faaad83 0.113s
2014-05-06 07:16:59.090 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:setUpClass): 200 POST http://192.168.1.170:35357/v2.0/tokens
2014-05-06 07:16:59.136 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:setUpClass): 200 GET http://192.168.1.170:35357/v2.0/OS-KSADM/roles 0.042s
2014-05-06 07:16:59.223 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_create_get_delete_token): 200 POST http://192.168.1.170:35357/v2.0/tenants 0.079s
2014-05-06 07:16:59.621 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_create_get_delete_token): 200 POST http://192.168.1.170:35357/v2.0/users 0.395s
2014-05-06 07:16:59.807 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_create_get_delete_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
2014-05-06 07:16:59.839 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_create_get_delete_token): 200 GET http://192.168.1.170:35357/v2.0/tokens/44f5873465d6476b934e17c2408ce596 0.029s
2014-05-06 07:16:59.939 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_create_get_delete_token): 204 DELETE http://192.168.1.170:35357/v2.0/tokens/44f5873465d6476b934e17c2408ce596 0.097s
.2014-05-06 07:17:00.236 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/users 0.292s
2014-05-06 07:17:00.353 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tenants 0.116s
2014-05-06 07:17:00.475 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tenants 0.119s
2014-05-06 07:17:00.575 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/OS-KSADM/roles 0.098s
2014-05-06 07:17:00.677 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 PUT http://192.168.1.170:35357/v2.0/tenants/62f398f37ea24d79a2fcea7ddce9d93a/users/c3a9603121a74c4f8365cd933dda828f/roles/OS-KSADM/0f0d8e9c481643b1bd9f5b719393512f 0.101s
2014-05-06 07:17:00.779 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 PUT http://192.168.1.170:35357/v2.0/tenants/e96f20300ee74e239ba883cc541f7dcc/users/c3a9603121a74c4f8365cd933dda828f/roles/OS-KSADM/0f0d8e9c481643b1bd9f5b719393512f 0.100s
2014-05-06 07:17:00.962 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
2014-05-06 07:17:01.128 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
2014-05-06 07:17:01.242 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 204 DELETE http://192.168.1.170:35357/v2.0/tokens/59124f087acf4d0c94ed1386d69cae85 0.110s
2014-05-06 07:17:01.370 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:test_rescope_token): 200 POST http://192.168.1.170:35357/v2.0/tokens
.2014-05-06 07:17:01.669 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/users/7758b537f6664479945eb50207458b4d 0.292s
2014-05-06 07:17:02.082 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/users/c3a9603121a74c4f8365cd933dda828f 0.411s
2014-05-06 07:17:02.180 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/tenants/3a676fc2c22642399391de764072c1c6 0.096s
2014-05-06 07:17:02.322 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/tenants/62f398f37ea24d79a2fcea7ddce9d93a 0.139s
2014-05-06 07:17:02.429 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/tenants/e96f20300ee74e239ba883cc541f7dcc 0.106s
2014-05-06 07:17:02.520 9543 INFO tempest.common.rest_client [-] Request (TokensTestXML:tearDownClass): 204 DELETE http://192.168.1.170:35357/v2.0/OS-KSADM/roles/0f0d8e9c481643b1bd9f5b719393512f 0.090s

----------------------------------------------------------------------
Ran 4 tests in 8.313s

OK
{% endhighlight %}
可以看到测试结果，4个测试，全部通过。

##一些问题和思考
* 测试报告如何归类
* 覆盖率如何统计
* 如果测试过程当中终止，测试数据如何清理
* ……
