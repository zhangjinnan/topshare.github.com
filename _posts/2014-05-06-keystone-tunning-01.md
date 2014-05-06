---
layout: post
title: "Keystone Performance简单测试和分析"
description: "还在用keystone默认wgsi提供接入的同学，赶紧换apahce的wgsi吧。早先时候写过一篇关于keystone把token这块从数据库移植到memcached。当时一直比较忙，没有深入的去研究一些问题。今天早上刚好把Rally玩了一下，keystone的数据有点惨，顺便做了一些keystone相关的tunning。后面看样子还是有很多工作要做，OpenStack测试任重道远呀。"
category: "OpenStack"
tags: [Rally, Keystone, OpenStack Tesing]
---
{% include JB/setup %}
早先时候写过一篇关于keystone把token这块从数据库移植到memcached。当时一直比较忙，没有深入的去研究一些问题。今天早上刚好把R
ally玩了一下，keystone的数据有点惨，顺便做了一些keystone相关的tunning。后面看样子还是有很多工作要做，OpenStack测试任重道远呀。本文也抛砖引玉，希望有更多的兄弟出来分享一些实际过程的经验。

##测试结果
下午新鲜出炉了keystone相关的测试数据，主要从两个方面对keystone进行了tunning，具体结果可以参考测试数据。

* memcached token存放
* apache替换keystone自身的wsgi

整个压力测试为了保证keystone还活着的情况下说明不同调整对性能的影响，采用10个并发用户，100个并发请求keystone创建和删除用户操作。

###apache wsgi + memcached token
{% highlight sh %}
(rally)[root@dev ~]# rally task detailed 3fe1e17c-0b20-4fe1-a8f9-a1664623da5e
/opt/rally/lib/python2.6/site-packages/Crypto/Util/number.py:57: PowmInsecureWarning: Not using mpz_powm_sec.  You should rebuild using libgmp >= 5 to avoid timing attack vulnerability.
  _warn("Not using mpz_powm_sec.  You should rebuild using libgmp >= 5 to avoid timing attack vulnerability.", PowmInsecureWarning)

================================================================================
Task 3fe1e17c-0b20-4fe1-a8f9-a1664623da5e is finished.
--------------------------------------------------------------------------------

test scenario KeystoneBasic.create_delete_user
args position 0
args values:
{u'args': {u'name_length': 10},
 u'runner': {u'concurrency': 10, u'times': 100, u'type': u'constant'}}
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+
| action                   | min (sec) | avg (sec) | max (sec) | 90 percentile | 95 percentile | success | count |
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+
| keystone.create_user     | 0.450     | 1.535     | 16.554    | 2.737         | 3.630         | 100.0%  | 100   |
| keystone.delete_resource | 0.118     | 0.258     | 1.632     | 0.343         | 0.438         | 100.0%  | 100   |
| total                    | 0.634     | 1.793     | 16.671    | 3.004         | 4.104         | 100.0%  | 100   |
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+

HINTS:
* To plot HTML graphics with this data, run:
	rally task plot2html 3fe1e17c-0b20-4fe1-a8f9-a1664623da5e --out output.html

* To get raw JSON output of task results, run:
	rally task results 3fe1e17c-0b20-4fe1-a8f9-a1664623da5e
{% endhighlight %}

详细的测试[结果](../../../../../assets/rallyresult/apache-memcache.html)。

###default wsgi + memcached token
{% highlight sh %}
(rally)[root@dev ~]# rally task detailed a3b96ed1-9ca6-4a73-9493-647077640ca1
/opt/rally/lib/python2.6/site-packages/Crypto/Util/number.py:57: PowmInsecureWarning: Not using mpz_powm_sec.  You should rebuild using libgmp >= 5 to avoid timing attack vulnerability.
  _warn("Not using mpz_powm_sec.  You should rebuild using libgmp >= 5 to avoid timing attack vulnerability.", PowmInsecureWarning)

================================================================================
Task a3b96ed1-9ca6-4a73-9493-647077640ca1 is finished.
--------------------------------------------------------------------------------

test scenario KeystoneBasic.create_delete_user
args position 0
args values:
{u'args': {u'name_length': 10},
 u'runner': {u'concurrency': 10, u'times': 100, u'type': u'constant'}}
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+
| action                   | min (sec) | avg (sec) | max (sec) | 90 percentile | 95 percentile | success | count |
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+
| keystone.create_user     | 1.789     | 4.670     | 7.861     | 6.588         | 7.194         | 100.0%  | 100   |
| keystone.delete_resource | 0.408     | 1.561     | 4.116     | 2.390         | 2.816         | 100.0%  | 100   |
| total                    | 3.202     | 6.231     | 10.239    | 8.146         | 8.891         | 100.0%  | 100   |
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+

HINTS:
* To plot HTML graphics with this data, run:
	rally task plot2html a3b96ed1-9ca6-4a73-9493-647077640ca1 --out output.html

* To get raw JSON output of task results, run:
	rally task results a3b96ed1-9ca6-4a73-9493-647077640ca1
{% endhighlight %}

详细的测试[结果](../../../../../assets/rallyresult/keystone-memcache.html)。

###default wsgi + sql token
{% highlight sh %}
(rally)[root@dev ~]# rally task detailed 496c7b17-08d6-4e32-a9ef-d8b9d4a0f9b5
/opt/rally/lib/python2.6/site-packages/Crypto/Util/number.py:57: PowmInsecureWarning: Not using mpz_powm_sec.  You should rebuild using libgmp >= 5 to avoid timing attack vulnerability.
  _warn("Not using mpz_powm_sec.  You should rebuild using libgmp >= 5 to avoid timing attack vulnerability.", PowmInsecureWarning)

================================================================================
Task 496c7b17-08d6-4e32-a9ef-d8b9d4a0f9b5 is finished.
--------------------------------------------------------------------------------

test scenario KeystoneBasic.create_delete_user
args position 0
args values:
{u'args': {u'name_length': 10},
 u'runner': {u'concurrency': 10, u'times': 100, u'type': u'constant'}}
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+
| action                   | min (sec) | avg (sec) | max (sec) | 90 percentile | 95 percentile | success | count |
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+
| keystone.create_user     | 2.020     | 5.514     | 9.456     | 7.309         | 7.925         | 100.0%  | 100   |
| keystone.delete_resource | 0.556     | 1.814     | 3.956     | 2.849         | 2.994         | 100.0%  | 100   |
| total                    | 3.977     | 7.329     | 11.938    | 9.321         | 10.110        | 100.0%  | 100   |
+--------------------------+-----------+-----------+-----------+---------------+---------------+---------+-------+

HINTS:
* To plot HTML graphics with this data, run:
	rally task plot2html 496c7b17-08d6-4e32-a9ef-d8b9d4a0f9b5 --out output.html

* To get raw JSON output of task results, run:
	rally task results 496c7b17-08d6-4e32-a9ef-d8b9d4a0f9b5
{% endhighlight %}

详细的测试[结果](../../../../../assets/rallyresult/keystone-sql.html)。

##测试结果分析
从上述的数据简单进行一下分析，可以看到，当采用apache wgsi的方式和keystone默认的wgsi的性能上看，平均创建用户场景的性能提升3倍左右，平均删除用户场景提升6倍的性能，整个场景提升的性能3.5倍。从这组数据来看，采用apache接管keystone wgsi服务毋容置疑的选择。还在用keystone自身wgsi服务的同学们，该鸟枪换炮了。

另外一个分析，对比采用keystone默认的wgsi+memcached存放token和sql存放token的数据。从两组数据分析来看，memcached存放token的效率整体优于sql存放token的性能，大约有17%的性能提升。

##目前已知的一些问题

* 整个测试在压力不高的情况下进行
* 当并发数量上去后，创建和删除的数量急剧增加，还需要调整apache的接入性能或者采用nginx
* 测试场景还比较单一，覆盖率不高
* 其它可调参数未知
* memcached存放token是否存在其它未知问题

