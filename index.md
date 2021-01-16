---
layout: page
title: 雪之痕，亦人生
tagline: prajna
---
{% include JB/setup %}
## 引言

往事不堪回首，当年的OpenStack已然成为全球最为火热的开源软件。遥想当年为啥选择OpenStack，貌似就因为自己不怎么喜欢桉树。当年在某个项目的选型当中，几乎就要选择了桉树，后来就仅仅因为我感觉OpenStack不错而选择了它。记得当时还只有D版本刚刚出来，貌似当时国内还没有人在生产上用这东西。现在想来，当初估计是年轻的轻狂，也硬着头皮把项目搞了下来。

OpenStack给我带来了全新的领域和全新的朋友，还记得当年满大街找做OpenStack的兄弟的时光。最后也就是寥寥几人，Intel的一波兄弟、新浪的一波（估计是我太渺小，始终未搭上线）、还有一波游兵散将（我也算一个吧）。搞了这么多年OpenStack后发现后起之秀很多，但那波老人到底还有多人个还奋斗在OpenStack的圈子里面，每每聊起来有一种伤感，酒不醉人人自醉。仅献给还在一线奋斗的OpenStack老人们，愿不远的将来OpenStack繁荣昌盛、遍地开花结果。Come on!

## 后记

*写于2021年1月16日23:15* 

发现引言已经都是5年前，OpenStack真的快十年了。近几年抓紧多看点课外书，多感受生活和今后10年的趋势是什么？

---
## 阅读
<table width="100%" rowspan="0" colspan="0">
<tr>
<td width="221px"><img src ="assets/image/openstack.jpg" alt="OpenStack"></td>
<td>
{% for openstack_post in site.categories.OpenStack limit:8 %}
<div width="100%"><a href="{{ BASE_PATH }}{{ openstack_post.url }}" class="openstack_url">{{ openstack_post.title }}
<br></a><span class="openstack_data">{{ openstack_post.date | date_to_string }} Kevin Zhang</span>
<br>
{{openstack_post.description}}
<div style="float:right;"><a href="{{ BASE_PATH }}{{ openstack_post.url }}">阅读全文</a></div>
<hr style="height:1px;border:none;border-top:1px dashed #0066CC;" />
</div>
{% endfor %}
<div style="width:50%;margin-left:auto;margin-right:auto;text-align:center;clear:both;">
    <a href="/archive.html">查看所有{{site.posts.size}}篇文章...</a>
</div>
</td>
</tr>
</table>
---
## 技术
<ul>
  {% for life_post in site.categories.TC limit:3 %}
    <li> {{ life_post.date | date_to_string }}&raquo; <a href="{{ BASE_PATH }}{{ life_post.url }}">{{ life_post.title }}</a></li>
  {% endfor %}
</ul>
---
## 生活

<ul>
  {% for life_post in site.categories.Life limit:3 %}
    <li> {{ life_post.date | date_to_string }}&raquo; <a href="{{ BASE_PATH }}{{ life_post.url }}">{{ life_post.title }}</a></li>
  {% endfor %}
</ul>
---