---
layout: post
title: "ansible学习"
description: "记录一下ansible学习过程中的问题和解决方法。"
category: "technique"
tags: [Python]
---
{% include JB/setup %}



## ansible第一次连接无法加入know_hosts

方法一：
~/.ansible.cfg配置增加 `host_key_checking = False`:
{% highlight sh %}
[defaults]
host_key_checking = False
{% endhighlight %}

方法二：
增加环境变量：
{% highlight sh %}
$ export ANSIBLE_HOST_KEY_CHECKING=False
{% endhighlight %}

## ansible第一个用法

### 批量对三个节点执行命令

创建一个Host Inventory






