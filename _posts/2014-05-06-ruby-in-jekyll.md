---
layout: post
title: "ruby in jekyll"
description: "在用github page的使用用到jekyll，本身这个用ruby写的，就顺便学习一下ruby的一些东西，顺便记录下来，便于自己以后学习之用。"
category: "Life"
tags: [Ruby, Git]
---
{% include JB/setup %}
在用github写博客的时候发现很多蛮有意思的东西，但这些东西都还需要自己慢慢的研究。这里主要对ruby的安装和本地jekyll的构建做一个简单的介绍，方便自己今后查阅。

##Ruby Install
可怜的mac用户，自从升级了Mac OS 10.9.2，我的ruby的bundler安装jekyll的依赖包就一直编译不过，花了点时间研究，发现是gcc的问题，没细致的去解决，实在是没时间。干脆就在Mac上安装了一个CentOS的虚拟机，在跑ruby，什么问题都没有，简单介绍一下安装过程和bundler的介绍。

###CentOS安装基础依赖包
{% highlight sh %}
kevinzhang:~ kevin# yum install gcc-c++ patch readline readline-devel zlib zlib-devel 
kevinzhang:~ kevin# yum install libyaml-devel libffi-devel openssl-devel make 
kevinzhang:~ kevin# yum install bzip2 autoconf automake libtool bison iconv-devel
{% endhighlight %}

###安装RVM
安装最新稳定版本的RVM对Ruby进行包进行管理和安装。
{% highlight sh %}
kevinzhang:~ kevin# curl -L get.rvm.io | bash -s stable
{% endhighlight %}

###设置RVM环境变量
{% highlight sh %}
kevinzhang:~ kevin# source /etc/profile.d/rvm.sh
{% endhighlight %}

###安装Ruby
{% highlight sh %}
kevinzhang:~ kevin# rvm install 2.1.1
{% endhighlight %}

###设置默认Ruby版本
{% highlight sh %}
kevinzhang:~ kevin# rvm use 2.1.1 default

Using /usr/local/rvm/gems/ruby-2.1.1

[root@dev ~]# rvm list

rvm rubies

=* ruby-2.1.1 [ x86_64 ]

{% endhighlight %}


###检查Ruby版本是否正确
{% highlight sh %}
kevinzhang:~ kevin# ruby -v
ruby 2.1.1p76 (2014-02-24 revision 45161) [x86_64-linux]
{% endhighlight %}

##bundle
在Ruby中引入了bundle来管理Ruby项目的gem依赖，可以看到jekyll项目也是采用这样的方式组织项目的gem依赖。那么如何采用bundle来管理gitpage的gem包依赖。可以查看blog根目录下的Gemfile和Gemfile.lock文件，文件内容如下：

Gemfile
{% highlight sh %}
[root@dev topshare.github.com]# cat Gemfile
source 'https://rubygems.org'
gem 'github-pages'
{% endhighlight %}

Gemfile.lock
{% highlight sh %}
[root@dev topshare.github.com]# cat Gemfile.lock
GEM
  remote: https://rubygems.org/
  specs:
    RedCloth (4.2.9)
    activesupport (4.0.4)
      i18n (~> 0.6, >= 0.6.9)
      minitest (~> 4.2)
      multi_json (~> 1.3)
      thread_safe (~> 0.1)
      tzinfo (~> 0.3.37)
    atomic (1.1.16)
    blankslate (2.1.2.4)
    classifier (1.3.4)
      fast-stemmer (>= 1.0.0)
    colorator (0.1)
    commander (4.1.6)
      highline (~> 1.6.11)
    fast-stemmer (1.0.2)
    ffi (1.9.3)
    gemoji (1.5.0)
    github-pages (17)
      RedCloth (= 4.2.9)
      jekyll (= 1.5.1)
      jekyll-mentions (= 0.0.6)
      jekyll-redirect-from (= 0.3.1)
      jemoji (= 0.1.0)
      kramdown (= 1.3.1)
      liquid (= 2.5.5)
      maruku (= 0.7.0)
      rdiscount (= 2.1.7)
      redcarpet (= 2.3.0)
    highline (1.6.21)
    html-pipeline (1.5.0)
      activesupport (>= 2)
      nokogiri (~> 1.4)
    i18n (0.6.9)
    jekyll (1.5.1)
      classifier (~> 1.3)
      colorator (~> 0.1)
      commander (~> 4.1.3)
      liquid (~> 2.5.5)
      listen (~> 1.3)
      maruku (= 0.7.0)
      pygments.rb (~> 0.5.0)
      redcarpet (~> 2.3.0)
      safe_yaml (~> 1.0)
      toml (~> 0.1.0)
    jekyll-mentions (0.0.6)
      html-pipeline (~> 1.5.0)
      jekyll (~> 1.4)
    jekyll-redirect-from (0.3.1)
      jekyll (~> 1.4)
    jemoji (0.1.0)
      gemoji (~> 1.5.0)
      html-pipeline (~> 1.5.0)
      jekyll (~> 1.4)
    kramdown (1.3.1)
    liquid (2.5.5)
    listen (1.3.1)
      rb-fsevent (>= 0.9.3)
      rb-inotify (>= 0.9)
      rb-kqueue (>= 0.2)
    maruku (0.7.0)
    mini_portile (0.5.3)
    minitest (4.7.5)
    multi_json (1.9.2)
    nokogiri (1.6.1)
      mini_portile (~> 0.5.0)
    parslet (1.5.0)
      blankslate (~> 2.0)
    posix-spawn (0.3.8)
    pygments.rb (0.5.4)
      posix-spawn (~> 0.3.6)
      yajl-ruby (~> 1.1.0)
    rb-fsevent (0.9.4)
    rb-inotify (0.9.3)
      ffi (>= 0.5.0)
    rb-kqueue (0.2.2)
      ffi (>= 0.5.0)
    rdiscount (2.1.7)
    redcarpet (2.3.0)
    safe_yaml (1.0.1)
    thread_safe (0.3.1)
      atomic (>= 1.1.7, < 2)
    toml (0.1.1)
      parslet (~> 1.5.0)
    tzinfo (0.3.39)
    yajl-ruby (1.1.0)

PLATFORMS
  ruby

DEPENDENCIES
  github-pages
{% endhighlight %}

所有project的信赖包都在Gemfile中进行配置，不再像以往那样，通过require来查找。这里可以看到整个项目依赖github-pages，如果github-pages有新的更新，可以通过bundle去更新依赖。
{% highlight sh %}
ot@dev topshare.github.com]# bundle update
Fetching gem metadata from https://rubygems.org/.........
Fetching additional metadata from https://rubygems.org/..
Resolving dependencies...
Using RedCloth 4.2.9
Using i18n 0.6.9
Using json 1.8.1
Using minitest 5.3.3
Using thread_safe 0.3.3
Using tzinfo 1.1.0
Installing activesupport 4.1.1 (was 4.1.0)
Using blankslate 2.1.2.4
Using fast-stemmer 1.0.2
Using classifier 1.3.4
Using colorator 0.1
Using highline 1.6.21
Using commander 4.1.6
Using ffi 1.9.3
Using gemoji 1.5.0
Using liquid 2.5.5
Using rb-fsevent 0.9.4
Using rb-inotify 0.9.4
Using rb-kqueue 0.2.2
Using listen 1.3.1
Using maruku 0.7.0
Using posix-spawn 0.3.8
Using yajl-ruby 1.1.0
Using pygments.rb 0.5.4
Using redcarpet 2.3.0
Using safe_yaml 1.0.3
Using parslet 1.5.0
Using toml 0.1.1
Using jekyll 1.5.1
Using mini_portile 0.5.3
Using nokogiri 1.6.1
Using html-pipeline 1.5.0
Using jekyll-mentions 0.0.6
Using jekyll-redirect-from 0.3.1
Using jekyll-sitemap 0.2.0
Using jemoji 0.1.0
Using kramdown 1.3.1
Using rdiscount 2.1.7
Using github-pages 18
Using bundler 1.6.2
Your bundle is updated!
{% endhighlight %}
这样bundle会去检查 http://rubygems.org/ 上 gem的最新版本，如果本地旧的话，会去更新到最近版本。然后同步更新Gemfile.lock

Gemfile.lock 则用来记录本机目前所有依赖的 RubyGems 和其版本，所以强烈建议将该文件放入版本控制器，从而保证大家基于同一环境下工作。

如果你需要锁定某个开发环境采用bundle lock锁定，使用bundle unlock解锁，不过貌似最新的bundle已经去除了这两个功能。
{% highlight sh %}
       These commands are obsolete and should no longer be used
       o   bundle lock(1)
       o   bundle unlock(1)
       o   bundle cache(1)
{% endhighlight %}

如果缺少gem包，如果检查：
{% highlight sh %}
[root@dev topshare.github.com]# bundle check
The Gemfile's dependencies are satisfied
{% endhighlight %}

##jekyll使用
新建一个jekyll：
{% highlight sh %}
[root@dev ~]# jekyll new abc
{% endhighlight %}

启动一个jekyll本地服务：
{% highlight sh %}
[root@dev topshare.github.com]# bundle exec jekyll serve -w
Configuration file: /root/code/topshare.github.com/_config.yml
            Source: /root/code/topshare.github.com
       Destination: /root/code/topshare.github.com/_site
      Generating... Maruku#to_s is deprecated and will be removed or changed in a near-future version of Maruku.
Maruku#to_s is deprecated and will be removed or changed in a near-future version of Maruku.
Maruku#to_s is deprecated and will be removed or changed in a near-future version of Maruku.
Maruku#to_s is deprecated and will be removed or changed in a near-future version of Maruku.

 ___________________________________________________________________________
| Maruku tells you:
+---------------------------------------------------------------------------
| Could not find ref_id = "indentifty" for md_link("compute", "indentifty")
| Available refs are []
+---------------------------------------------------------------------------
!/usr/local/rvm/gems/ruby-2.1.1/gems/maruku-0.7.0/lib/maruku/output/to_html.rb:649:in `to_html_link'
!/usr/local/rvm/gems/ruby-2.1.1/gems/maruku-0.7.0/lib/maruku/output/to_html.rb:882:in `block in array_to_html'
!/usr/local/rvm/gems/ruby-2.1.1/gems/maruku-0.7.0/lib/maruku/output/to_html.rb:870:in `each'
!/usr/local/rvm/gems/ruby-2.1.1/gems/maruku-0.7.0/lib/maruku/output/to_html.rb:870:in `array_to_html'
\___________________________________________________________________________

Not creating a link for ref_id = "indentifty".

done.
 Auto-regeneration: enabled
    Server address: http://0.0.0.0:4000
  Server running... press ctrl-c to stop.
{% endhighlight %}

##发个文章：
{% highlight sh %}
[root@dev topshare.github.com]# rake post title="abc"
Creating new post: ./_posts/2014-05-06-abc.md
{% endhighlight %}
根据markdown编辑2014-05-06-abc.md文件最后提交到github即可。

##References:
http://rvm.io/rubies/installing
