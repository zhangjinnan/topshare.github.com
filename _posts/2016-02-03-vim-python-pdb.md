---
layout: post
title: "python开发工具和调试"
description: "记录在python开发过程中使用的工具和调试手段。"
category: "technique"
tags: [Python]
---
{% include JB/setup %}
Python的开发工具多种多样，本文主要就自己开发过程中的一些工具做一些简单说明。主要工具有vim + ctags + pdb，通过这些小工具，组装成最适合自己的IDE。

##git配置

{% highlight sh %}
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.ci commit
git config --global alias.cm "commit --amend"
git config --global alias.br branch
git config --global alias.last "log -1 HEAD"
{% endhighlight %}


##vim使用
vim尽量用最简单的配置，主要的配置如下：

{% highlight sh %}
" enable syntax highlighting
syntax enable
" show line numbers
set number
" set tabs to have 4 spaces
set ts=4
" indent when moving to the next line while writing code
set autoindent
" expand tabs into spaces
set expandtab
" when using the >> or << commands, shift lines by 4 spaces
set shiftwidth=4
" show a visual line under the cursor's current line
set cursorline
" show the matching part of the pair for [] {} and ()
set showmatch
" enable all Python syntax highlighting features
let python_highlight_all = 1
{% endhighlight %}


| 快捷键   | 使用说明            | 备注 |
|----------|---------------------|------|
| */#      | 选择当前光标单      |      |
| crtl+n   | 单词补全            |      |

##ctags使用

| 快捷键   | 使用说明            | 备注 |
|----------|---------------------|------|
| crtl+]   | 跳到下个函数        |      |
| crtl+o/t | 返回上个函数        |      |
| ts       | 查找出现的函数位置  |      |


##pdb使用

{% highlight sh %}
ipmort pdb
pdb.set_trace()
{% endhighlight %}


