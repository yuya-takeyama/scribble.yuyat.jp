---
layout: article
title: "Redmine 1.4 を CentOS 5 にインストールしたときの作業メモ"
---
### 目標

古いバージョンで動いている Redmine をアップグレードしたいので, 必要な手順等について調べる.

でもまずは新規インストールができるようになる.

### 構成

以下のような構成にします.

- さくら VPS (980)
- CentOS release 5.8 (Final)
- Ruby 1.9.3-p125
- Redmine 1.4.1
- Apache 2
- Phusion Passenger (mod_passenger)

さくら VPS 月額 980 円でメモリ 1GB HDD 100GB とかすごいですね.

以下の記事を参考にしました.

- [Redmine 1.4をCentOS 6にインストールする手順](http://blog.redmine.jp/articles/redmine-1_4-installation_centos/)

### 元の記事との相違点

基本的にグローバルな環境をなるべく汚さないことを意識しています.

- Ruby は ruby-build と rbenv で入れる
- RMagick は諦める (yum で入る ImageMagick が古い)
- Gem は ./vendor ディレクトリにインストールする
- Passenger も Bundler でインストールする
- Redmine は tarball でなく Git でインストールする
- chown -R apache:apache はしない (しなくても問題無く動作する)

### 事前準備

GCC などをインストールする.

{% highlight bash %}
$ sudo yum -y update
$ sudo yum -y install gcc kernel-devel zlib-devel openssl-devel readline-devel curl-devel libyaml-devel
{% endhighlight %}

### EPEL を追加する

CentOS は大体に置いて, 提供されるパッケージのバージョンが古い印象がありますね.

そのあたりの事情について以下の記事が大変参考になりました.

- EPEL リポジトリを活用して CentOS 5.x で Python 2.6 をインストールする (http://d.hatena.ne.jp/t2y-1979/20110430/1304140587)

つまりは EPEL というリポジトリを使うようにすると, CentOS でも割と新しめのバージョンのパッケージを, 割と安心してインストールできるということでしょうか.

というわけで入れてみました.

{% highlight bash %}
$ sudo rpm -Uvh http://ftp.jaist.ac.jp/pub/Linux/Fedora/epel/5/i386/epel-release-5-4.noarch.rpm
{% endhighlight %}

先に紹介した記事同様, デフォルトでは使用しないように /etc/yum.repos.d/epel.repo で epel の enabled を 0 にしています.

### MySQL のインストール

{% highlight bash %}
$ sudo yum -y install mysql-server mysql-devel
{% endhighlight %}

設定は基本的にブログ記事と同様.  
ユーザ名・データベース名は redmine とした.

### Apache のインストール

{% highlight bash %}
$ sudo yum -y install httpd httpd-devel
{% endhighlight %}

### Git のインストール

{% highlight bash %}
$ sudo yum -y install git --enablerepo epel
{% endhighlight %}

### Ruby のインストール

CentOS 5 だと Ruby 1.9 をパッケージで入れることはできなさげなので, ruby-build と rbenv を使ってホームディレクトリ内にインストールすることにする.  
それぞれのインストール手順は README の通りなので省略する.  
ruby-build は root としてインストールし, rbenv は redmine ユーザとしてインストールする.

ruby-build と rbenv のインストールが完了したら rbenv で Ruby 1.9.3 をインストールする.

{% highlight bash %}
$ rbenv install 1.9.3-p125
$ rbenv global 1.9.3-p125
{% endhighlight %}

Redmine が Bundler に対応したのでそれも入れる.

{% highlight bash %}
$ gem install bundler --no-ri --no-rdoc
{% endhighlight %}

### Redmine のインストール

GitHub のミラーリポジトリから入れる.

ホームディレクトリなどにインストールしてしまうと Apache から実行するときに困るので, 今回は /var/redmine にインストールする.

{% highlight bash %}
$ cd /var
$ sudo mkdir redmine
$ sudo chown redmine:redmine redmine
$ cd redmine
$ git clone https://github.com/redmine/redmine.git .
$ git checkout 1.4-stable
{% endhighlight %}

./config ディレクトリの設定については概ねブログ記事の通りだが, Ruby 1.9 の場合は adapter を mysql2 にしないといけないことに注意が必要.

### Gem パッケージのインストール

Bundler を使う.  
元の記事では 指定していないが --path オプションを指定してローカルディレクトリにインストールしている.  
(指定しないと gem コマンドでインストールするのと同じ領域にインストールされてしまう)

yum で入る ImageMagick のバージョンが古くて RMagick が入れられないので, rmagick も無効化.  
Optional な gem なので問題無い.

{% highlight bash %}
$ bundle install --without development test postgresql sqlite rmagick --path vendor/bundler
{% endhighlight %}

### Redmine の初期設定

元の記事では rake を直接実行しているが, gem を ./vendor にインストールしているので bundle exec rake する必要がある.

{% highlight bash %}
$ bundle exec rake generate_session_store
$ bundle exec rake db:migrate RAILS_ENV=production
{% endhighlight %}

### Phusion Passenger のインストール

Passenger も Bundler で入れてみる.

Gemfile.local を以下のようにする.

{% highlight ruby %}
gem "passenger"
{% endhighlight %}

そしてインストール.

{% highlight bash %}
$ bundle update
$ bundle exec passenger-install-apache2-module
{% endhighlight %}

適当に進めると mod_passenger がビルドされる.
Passenger の設定は /etc/httpd/conf.d/passenger.conf に記載した.

基本的にはブログ記事の通り.  
mod_passenger.so 等に関する設定は bundle exec passenger-install-apache2-module --snippet すれば確認できる.

### Apache の設定

VirtualHost 等を適当に設定する.  
DocumentRoot を ./public (もちろん実際はフルパス) に指定するぐらいで OK.

とりあえず普通のインストールができたので, 次は古いバージョンからのアップグレードとか, Bundler を使ったプラグインのインストールとかについて調べる.
