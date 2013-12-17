---
layout: post
title: "如何使keystone更有效率"
description: ""
category: "openstack"
tags: [keystone, performance]
---
{% include JB/setup %}

#写在前面……
最近在测试OpenStack Havana RDO版本的时候，发现过一段时间后，整个平台会变动的越来越慢。刚刚开始还没什么动力去trouble shooting，毕竟就一demo的环境。昨天居然给让我无法访问，这就不能忍了，得看看是什么臭虫在捣鬼。

##keystne Token的问题
无意中发现在Nova API调用的过程当中，在向keystone获取Token的时间会异常的长。而当我刚刚安装完keystone的时候，整个速度还是很不错的。查阅了相关的资料，发现Token这块在数据库永久存放，而且增长速度还是很快，对keystone的数据库的表分析如下：

切换到MySQL自带管理库information_schema

    mysql> use information_schema;
    Reading table information for completion of table and column names
    You can turn off this feature to get a quicker startup with -A

    Database changed

查看Token的大小：

    mysql> select data_length,index_length from tables where table_schema='keystone'
    -> and table_name='token';
    +-------------+--------------+
    | data_length | index_length |
    +-------------+--------------+
    |   916455424 |     17924096 |
    +-------------+--------------+
    1 row in set (0.01 sec)

用比较直观的方式查看：

    mysql> select concat(round(sum(data_length/1024/1024),2),'MB') as data_length_MB,
    -> concat(round(sum(index_length/1024/1024),2),'MB') as index_length_MB
    -> from tables where
    -> table_schema='keystone'
    -> and table_name='token';
    +----------------+-----------------+
    | data_length_MB | index_length_MB |
    +----------------+-----------------+
    | 874.00MB       | 17.09MB         |
    +----------------+-----------------+
    1 row in set (0.01 sec)
大概两周的时间，居然有近1G的数据，当然，1G对于数据库来说也是小case，但如果是一年，这个数据量也是不容忽视的。

在看一下keystone对于token的配置`keystone.conf`，主要有几部分：

    [token]
    # Provides token persistence.
    driver = keystone.token.backends.sql.Token
    # driver = keystone.token.backends.memcache.Token

    # Controls the token construction, validation, and revocation operations.
    # Core providers are keystone.token.providers.[pki|uuid].Provider
    # provider =

    # Amount of time a token should remain valid (in seconds)
    expiration = 86400

从上述的配置可以token默认存放在数据库中，默认过期时间为为一天。当然，在launchpad上有很多朋友提到用脚本清除数据库即可。
##采用清除token表的方式解决问题
这边的话，也借鉴了一下他们的经验去解决这个问题，下面是清除token表的脚本。
 
    #!/bin/bash

    mysql_user=
    mysql_password=
    mysql_host=
	#这里大家可以考虑一下清除数据的时间的问题，为啥是2天
    mysql -u${mysql_user} -p${mysql_password} -h${mysql_host} -e 'USE keystone ; DELETE FROM token WHERE NOT DATE_SUB(CURDATE(),INTERVAL 2 DAY) <= expires;'

当然，如果你在清除token的时候不幸遇到如下的错误：
    
    ERROR 1205 (HY000) at line 1: Lock wait timeout exceeded; try restarting transaction
只需要增加`innodb_lock_wait_timeout`的值：
    
    mysql> show variables like 'innodb_lock_wait_timeout';
    +--------------------------+-------+
	| Variable_name            | Value |
	+--------------------------+-------+
	| innodb_lock_wait_timeout | 50    |
	+--------------------------+-------+
	1 row in set (0.00 sec)

	mysql> set innodb_lock_wait_timeout=100;
	Query OK, 0 rows affected (0.00 sec)

	mysql> show variables like 'innodb_lock_wait_timeout';
	+--------------------------+-------+
	| Variable_name            | Value |
	+--------------------------+-------+
	| innodb_lock_wait_timeout | 100   |
	+--------------------------+-------+
重新运行上面的脚本即可。

当然，兄弟们不能每次自己手动去服务器上执行这个脚本，采用crontab+脚本的方式，脚本`clearToken.sh`。

	#!/bin/bash

	mysql_user=keystone
	mysql_password=********
	mysql_host=
	mysql=$(which mysql)

	logger -t keystone-cleaner "Starting Keystone 'token' table cleanup"

	logger -t keystone-cleaner "Starting token cleanup"
	mysql -u${mysql_user} -p${mysql_password} -h${mysql_host} -e 'USE keystone ; DELETE FROM token WHERE NOT DATE_SUB(CURDATE(),INTERVAL 2 DAY) <= expires;'
	valid_token=$($mysql -u${mysql_user} -p${mysql_password} -h${mysql_host} -e 'USE keystone ; SELECT * FROM token;' | wc -l)
	logger -t keystone-cleaner "Finishing token cleanup, there is still $valid_token valid tokens..."

	exit 0

crontab的定时任务：

	[root@controller01 keystone]# cat /etc/crontab
	SHELL=/bin/bash
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	MAILTO=root
	HOME=/

	# For details see man 4 crontabs

	# Example of job definition:
	# .---------------- minute (0 - 59)
	# |  .------------- hour (0 - 23)
	# |  |  .---------- day of month (1 - 31)
	# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
	# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
	# |  |  |  |  |
	# *  *  *  *  * user-name command to be executed
	0 1 * * * /opt/clearToken.sh
##Memcached存放Token
为了给MySQL的token表瘦身，可以后端采用Memcached作为Token的存储后端。但采用Memcached作为后端的存储。但Memcached这块，目前还是有些问题：

* Token在Memcached中是否永久存储？
* 当Memcached宕机时，Cache无法持久化
* Memcached采用集群复制，如何去做？
* Memcached效率如何？

###Memcached使用OpenStack
安装Memcached服务：
	
	yum -y install memcached
	
修改`keystone.conf`配置文件：

	[token]
	driver = keystone.token.backends.memcache.Token
重启服务：

	service memcached restart
	service openstack-keystone restart
检查是否work：
	
	[root@controller01 ~]# lsof -i :11211
	COMMAND     PID      USER   FD   TYPE   DEVICE SIZE/OFF NODE NAME
	keystone-  6658  keystone   10u  IPv4 20381693      0t0  TCP localhost:41865->localhost:memcache (ESTABLISHED)
	keystone-  6658  keystone   12u  IPv4 19947698      0t0  TCP localhost:33995->localhost:memcache (ESTABLISHED)
	keystone-  6658  keystone   14u  IPv4 20140990      0t0  TCP localhost:37472->localhost:memcache (ESTABLISHED)
	keystone-  6658  keystone   20u  IPv4 20333522      0t0  TCP localhost:40973->localhost:memcache (ESTABLISHED)
	memcached 28336 memcached  126u  IPv4  3050900      0t0  TCP *:memcache (LISTEN)
	memcached 28336 memcached  127u  IPv4  3050902      0t0  UDP *:memcache
	memcached 28336 memcached  128u  IPv4 20381696      0t0  TCP localhost:memcache->localhost:41865 (ESTABLISHED)
	memcached 28336 memcached  129u  IPv4 19947701      0t0  TCP localhost:memcache->localhost:33995 (ESTABLISHED)
	memcached 28336 memcached  130u  IPv4 20140993      0t0  TCP localhost:memcache->localhost:37472 (ESTABLISHED)
	memcached 28336 memcached  133u  IPv4 20333525      0t0  TCP localhost:memcache->localhost:40973 (ESTABLISHED)
可以看到keystone已经和memcached建立了TCP连接。

可以用telnet查看memcached中的token的信息：

    root@controller01 ~]# telnet 127.0.0.1 11211
    Trying 127.0.0.1...
    Connected to 127.0.0.1.
    Escape character is '^]'.
    stats items
    STAT items:9:number 1
    STAT items:9:age 19766
    STAT items:9:evicted 0
    STAT items:9:evicted_nonzero 0
    STAT items:9:evicted_time 0
    STAT items:9:outofmemory 0
    STAT items:9:tailrepairs 0
    STAT items:11:number 62
    STAT items:11:age 81982
    STAT items:11:evicted 0
    STAT items:11:evicted_nonzero 0
    STAT items:11:evicted_time 0
    STAT items:11:outofmemory 0
    STAT items:11:tailrepairs 0
    STAT items:15:number 1
    STAT items:15:age 20365
    STAT items:15:evicted 0
    STAT items:15:evicted_nonzero 0
    STAT items:15:evicted_time 0
    STAT items:15:outofmemory 0
    STAT items:15:tailrepairs 0
    STAT items:17:number 1
    STAT items:17:age 20287
    STAT items:17:evicted 0
    STAT items:17:evicted_nonzero 0
    STAT items:17:evicted_time 0
    STAT items:17:outofmemory 0
    STAT items:17:tailrepairs 0
    STAT items:18:number 8558
    STAT items:18:age 7675
    STAT items:18:evicted 0
    STAT items:18:evicted_nonzero 0
    STAT items:18:evicted_time 0
    STAT items:18:outofmemory 0
    STAT items:18:tailrepairs 0
    STAT items:22:number 1
    STAT items:22:age 81605
    STAT items:22:evicted 0
    STAT items:22:evicted_nonzero 0
    STAT items:22:evicted_time 0
    STAT items:22:outofmemory 0
    STAT items:22:tailrepairs 0
    STAT items:28:number 1
    STAT items:28:age 81982
    STAT items:28:evicted 0
    STAT items:28:evicted_nonzero 0
    STAT items:28:evicted_time 0
    STAT items:28:outofmemory 0
    STAT items:28:tailrepairs 0
    STAT items:36:number 1
    STAT items:36:age 82020
    STAT items:36:evicted 0
    STAT items:36:evicted_nonzero 0
    STAT items:36:evicted_time 0
    STAT items:36:outofmemory 0
    STAT items:36:tailrepairs 0
    END

    stats cachedump 18 100
	ITEM token-9be5243e6765408bb67cd73f66367cdd [3827 b; 1387340643 s]
	ITEM token-499d93bec0a54ddebdc28ef0941ba7df [3827 b; 1387340702 s]
	ITEM token-186a1394b2474c998dafc752fd80d058 [3827 b; 1387340700 s]
	ITEM token-3de99c3d4f174d15a1546ce321d1e3a1 [3824 b; 1387340576 s]
	ITEM token-fcab58d23ff94369b27a8dc335340028 [3824 b; 1387340697 s]
	ITEM token-7092f681ebe34cae9830eba8ae7d45f3 [3824 b; 1387340636 s]
	ITEM token-977cf2ab85e54920b3d3b582dabba7d8 [3824 b; 1387340634 s]
	ITEM token-49df94c6ef7a4a1582c7539f5829b354 [3824 b; 1387340567 s]
	ITEM token-7b1f9646734542d5a30dd0cbc8d1937d [3824 b; 1387340569 s]
	……

可以看到，目前items:18存放的是token信息。


##后面可以干什么
你可以看到，关于keystone其实在实际用过的过程当中会遇到很多的问题，这些问题怎么去处理将是在生产环境是否能真正用好的关键。目前的OpenStack不该处于实验室的产品，应该更向生产环境迈进，那后面我们该做什么，怎么去做？

###keystone的performance
对于keystone的performance的问题，其实社区也在讨论这块的东西，如何去做performance的测试，怎么去tunning，这都是一个话题，后面会针对于keystone这块如何去测试，如果调整性能做一些分析，希望对大家有帮助。
