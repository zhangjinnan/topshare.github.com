---
layout: post
title: "ansible学习"
description: "记录一下ansible学习过程中的问题和解决方法。"
category: "TC"
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

创建一个Host Inventory `multinode`
{% highlight sh %}
[control]
# These hostname must be resolvable from your deployment host
zjn01
zjn02
zjn03
{% endhighlight %}

### 远程修改sshd配置
{% highlight sh %}
[root@zjn-deploy workstation]# ansible -i multinode all -m shell -a "echo 'UseDNS no' >> /etc/ssh/sshd_config;systemctl restart sshd"
{% endhighlight %}


## playbook执行

传参数的方式执行一个playbook，例如：

{% highlight sh %}
state: "{{ status }}"
ansible-playbook -e state=present/absent
{% endhighlight %}


