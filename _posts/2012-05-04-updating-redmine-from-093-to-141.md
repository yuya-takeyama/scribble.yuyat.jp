---
layout: article
title: "Redmine を 0.9.3 から 1.4.1 にアップグレードしたときのメモ"
---
GW 2 日目もバンドラーにジェムやレイルズアプリと戦っていました.

### 目標

古いバージョンで動いている Redmine をアップグレードする.

具体的には 0.9.3 を サーバは WEBRick データベースは SQLite という構成で動かしていて, 当初はこれでも十分だったけど, 年数が経ってくるにつれて辛くなってきたので 1.4.1 で Apache x Passenger で MySQL という構成にする.

### ぶつかった問題点

個々のステップの前に, やり遂げるまでにぶつかった問題点を先に挙げる.

- rake db:migrate とかデータの移行とかをどういう順序で行うべきかよくわかっていなかった
- データベースの変換をどうするか
- Redmine 1.4 になってプラグインの仕様が変わっていた (プラグイン毎に ./config/routes.rb が必要になった)

データ移行については, 移行対象のデータが割と大きかったせいで試行錯誤の度に時間がかかってしまった.

プラグインの仕様変更については, Rails 力も Redmine 力も低い自分にとってはどうしようかという感じだったが, プラグイン作者様が既に対応してくれていたり, 対応されていないものでも比較的容易に対応できたので何とかなった.

[前日](/2012/05/03/redmine-installation-on-centos-5.html)に Redmine/Rails 以前の問題を解決していおいたおかげで, そういった問題に悩まされることが無かった点は良かった.

### 最終的な手順

試行錯誤した結果, 以下の手順でうまくいった.

なお, サーバ構成や, 使用するツール (Bundler とか) については前日の記事と同様としている.

1. 移行先のサーバに Git で Redmine のワークツリーを展開. 1.4.1 としてタグ付けされたものを使用.
2. プラグインはできる限り最新バージョンのものを ./vendor/plugins ディレクトリに展開しておく. 仕様変更への対応が必要なものはそれを行う.
3. SQLite の DB ファイルを ./db/production.db として元のサーバからコピー.
4. ./config/database.yml で production の設定をコピーしてきた production.db を読むようにする.
5. ./config/email.yml の設定を ./config/configuration.yml に移動する. (Redmine の仕様変更)
6. bundle exec rake db:migrate RAILS_ENV=production してスキーマを 1.4.1 の状態にする.
7. bundle exec rake db:migrate:upgrade_plugin_migrations RAILS_ENV=production
8. bundle exec rake db:migrate_plugins RAILS_ENV=production ここでスキーマが正しい状態になる (ただし SQLite)
9. bundle exec script/plugin install git://github.com/adamwiggins/yaml_db.git して [yaml_db](https://github.com/adamwiggins/yaml_db) をインストール. DB の変換に使う.
10. bundle exec rake db:dump RAILS_ENV=production して production.db を YAML 形式にダンプ. ./db/data.yml として出力される.
11. ./config/database.yml を書き換えて production のデータベースを MySQL にする.
12. bundle exec rake db:load RAILS_ENV=production して ./db/data.yml を MySQL に書き出す.
13. 前日の手順で Passenger のインストール/起動.

これで今のところは問題無く動作している.

### rake db:migrate とかについて

最初は rake db:migrate の前に yaml_db によるデータ変換を行ったりしていたが, これだと何故か rake db:migrate_plugins のときにエラーになってどうしようもできなくなった.

エラーメッセージを見る限りでは, 既にある Code Review プラグイン用の code_reviews テーブルを再度作成しようとして失敗していることはわかった.  
でも何故そんな問題が起こるのかはよくわからなかった.  
既に実行された migration は schema_migrations テーブルに記録されるからこういうことは起こらないようになっているものかと思っていたのだけど.

ともかく rake db:migrate を先に一通りやって, スキーマを最新の状態にしてから MySQL に変換することでうまくいくようになった.

### データベースの変換について

前述の通り [yaml_db](https://github.com/adamwiggins/yaml_db) を使っている.

以下の記事が参考になった.

- [Redmine(Rails) の DB を SQLite3 から MySQL に移行する](http://garin.jp/doc/Ruby/Redmine/sqlite3tomysql)

yaml_db 自体は Redmine だけじゃなくて Rails アプリ一般に使えるようなので便利だと思った.  
Rails3 でも使えるのかはよく知らない.

### プラグインの仕様変更について

Redmine 1.4 でルーティングに関する仕様変更が行われ, ほとんどのプラグインで対応が必要らしい.

- [Redmine 1.4.0のrouteエラーを回避する](http://haruiida.blogspot.jp/2012/04/redmine-140route.html)
- [Redmine 1.4.0 もうすぐリリース。大量のプラグインが動作しない可能性あり](http://yohshiy.blog.fc2.com/blog-entry-113.html)

これまでは Redmine 全体の ./config/routes.rb で行われていたルーティングが, プラグインごとの ./config/routes.rb に委譲されるようになった, ということらしい.

[Wiki Extensions](http://www.r-labs.org/projects/r-labs/wiki/Wiki_Extensions) や [Redmine Code Review プラグイン](http://www.r-labs.org/projects/r-labs/wiki/Code_Review) では対応が行われていたので, 新しいバージョンにアップグレードするだけで解決した.

[ゴンペルたん](http://chocoapricot.cocolog-nifty.com/blog/2008/08/redmine_3_ca3c.html) については対応が行われていなかったが, 以下のような ./config/routes.rb を用意することでとりあえず解決したようだ.

{% highlight ruby %}
ActionController::Routing::Routes.draw do |map|
  map.connect 'projects/:id/gompertan/:action', :controller => 'gompertan'
end
{% endhighlight %}

ゴンペルたんのようにシンプルなプラグインであればこれで大体解決するらしい.

### まとめ

- とりあえず rake db:migrate 系を先に済ませてスキーマを最新の状態にしておく
- yaml_db 便利
- Redmine 1.4 以降にアップグレードする際はプラグインの仕様変更に注意が必要

### その他

いつの間にかガントチャートのチケットがプロジェクトやバージョンでグループ化されるようになっていた.

開発者たちの努力によるものだということは想像できるが, 開始日や期日でソートができないと辛い.  
正直言って改悪だと感じた.

デフォルトは従来の開始日ソートに戻して欲しい.
