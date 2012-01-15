---
layout: article
title: "Mac に CGDB をインストール"
---
ひたすら Vim でコードリーディングに疲れてきたので CGDB を導入.  
Homebrew にあったのですぐできた.

{% highlight bash %}
$ brew install cgdb
Warning: It appears you have MacPorts or Fink installed.
Software installed with other package managers causes known problems for
Homebrew. If a formula fails to build, uninstall MacPorts/Fink and try again.
==> Downloading http://downloads.sourceforge.net/project/cgdb/cgdb/cgdb-0.6.5/cgdb-0.6.5.tar.gz
######################################################################## 100.0%
==> Downloading patches
######################################################################## 100.0%
######################################################################## 100.0%
==> Patching
patching file various/util/src/pseudo.c
patching file various/rline/src/Makefile.in
patching file various/rline/src/rline.c
==> ./configure --disable-debug --prefix=/usr/local/Cellar/cgdb/0.6.5 --with-readline=/usr/local/Cella
==> make install
ln: dir: Permission denied
Error: The linking step did not complete successfully
The formula built, but is not symlinked into /usr/local
You can try again using `brew link cgdb'
==> Summary
/usr/local/Cellar/cgdb/0.6.5: 9 files, 396K, built in 28 seconds
{% endhighlight %}

エラーが出はいるが正常に /usr/local/bin/cgdb ができており, 問題なく cgdb コマンドを実行することができた.  
何でしょうね.

実際のデバッグ作業については以下の記事を参考にした.

- [vim使い向けのGDBフロントエンド、CGDBが便利という話](http://d.hatena.ne.jp/anatoo/20111023/1319375779)
- [GDBデバッガを利用してPHP内部の動きを知る - PHPソースコードリーディング入門その2](http://d.hatena.ne.jp/anatoo/20111117/1321463886)

![Debugging PHP with CGDB](/image/2012-01-15-debugging-php-with-cgdb.png)

上部の画面でブレークポイントの設定やソースコードリーディングを行いながら, 下部の画面ではコマンド入力を行い, 変数の中身を除いたりできた.  
これは PHP の count 関数の中で HashTable 構造体を除いている様子.

構造体のメンバを参照するときに, s->m でも s.m でも特に変わらないようだ. (マジで?)  
連結リストを辿って行くような操作もかなり簡単にできる.

ただ, GNU screen 上で起動すると画面が崩れてしまうので, 仕方なく iTerm2 を別途起動して, そこで実行している.  
何とかならないものものか. (CGDB に限らないけど)

VM に入れている Ubuntu 上でも aptitude で簡単にインストールできたので, 環境を用意する手間はほとんど無いと言っていい.  
これから活用していきたい.
