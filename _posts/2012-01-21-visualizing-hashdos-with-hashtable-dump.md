---
layout: article
title: "HashDoS を可視化する PHP 拡張 hashtable_dump 書いた"
---
2011 年の年末に HashDoS というのが話題になった.

- [Webアプリケーションに対する広範なDoS攻撃手法(hashdos)の影響と対策](http://blog.tokumaru.org/2011/12/webdoshashdos.html)

要するにハッシュテーブルキーののハッシュ値を意図的に衝突させることで非効率な挿入を行わせることで, 効率的にサービスを妨害する, というものだ.

ということをドヤ顔で書いてはいるが, 年末の時点ではこの HashDoS の原理については理解しておらず, 「データ構造を偏らせて計算量を増やすんだろう」ぐらいの漠然としたイメージしか無かった.

その後, PHP の HashTable 構造体や, 一般的なハッシュテーブルの実装について調べることで, HashDoS の原理がわかってきた.  
ハッシュテーブルについては, いくつかの解説ページを見ながら, サンプルコードを Ruby に翻訳することで学習した.  

- [アルゴリズムとデータ構造編　第１４章　ハッシュ探索①（チェイン法）](http://www.geocities.jp/ky_webid/algorithm/014.html)
- [アルゴリズムとデータ構造編　第１５章　ハッシュ探索②（オープンアドレス法）](http://www.geocities.jp/ky_webid/algorithm/015.html)
- [Ruby でハッシュテーブルを実装する](http://qiita.com/items/1607)
- [Ruby でハッシュテーブルを実装する (オープンアドレス法)](http://qiita.com/items/1613)
- [Ruby で双方向リスト](http://qiita.com/items/1731)

PHP の HashTable 構造体は双方向リストを用いたハッシュテーブルとなっている.  
キーのハッシュ値を元に要素を格納するスロットが決まり, そのスロットに既に要素が存在する場合は, そのスロット内の双方向リストの先頭に値を挿入する.

...という説明では上手く伝えきれないので, これを可視化する PHP 拡張を書いた.

- [hashtable\_dump](https://github.com/yuya-takeyama/hashtable_dump)

hashtable\_dump\(\) 関数は引数として array 型の値を受け取り, HashTable 構造体レベルで内部の情報を出力する.

{% highlight php %}
<?php
hashtable_dump(array(1, 2, 3, 4, 5, 6, 7, 8));
/*
nTableSize:       8
nTableMask:       7
nNumOfElements:   8
nNextFreeElement: 8
pListHead:        0
pListTail:        7
**arBuckets:
  0 => [0, NULL]
  1 => [1, NULL]
  2 => [2, NULL]
  3 => [3, NULL]
  4 => [4, NULL]
  5 => [5, NULL]
  6 => [6, NULL]
  7 => [7, NULL]
*/
{% endhighlight %}

いずれも HashTable 構造体のメンバに対応するものだ. 出力している内容は以下の通り.

- nTableSize: ハッシュテーブルのスロット数. 最少で 8, 必要に応じて 2 倍ずつ拡張される.
- nTableMask: 値を格納するスロットを格納するためのビット演算に使用する値. 常に nTableSize より 1 小さい値.
- nNumOfElements: ハッシュテーブル内に存在する要素の数.
- nNextFreeElement: $hash[] = 'foo'; としたときに, 暗黙的に指定されるキー.
- pListHead: ハッシュテーブル内の先頭要素のキー.
- pListTail: ハッシュテーブル内の末尾要素のキー.
- \*\*arBuckets: Bucket 構造体へを指すポインタの配列. スロットの一覧と, その中に存在するキーを出力している.

配列が空のときは, 以下のようになる.

{% highlight php %}
<?php
hashtable_dump(array());
/*
nTableSize:       8
nTableMask:       7
nNumOfElements:   0
nNextFreeElement: 0
pListHead:        NULL
pListTail:        NULL
**arBuckets:
  0 => [NULL]
  1 => [NULL]
  2 => [NULL]
  3 => [NULL]
  4 => [NULL]
  5 => [NULL]
  6 => [NULL]
  7 => [NULL]
*/
{% endhighlight %}

空なので, リストの先頭も末尾も NULL を指し, いずれのスロットにも値が無い. (NULL しか無い)

値の格納先のスロットは以下のようなビット演算で算出される.

{% highlight cpp %}
hashKey & nTableMask
{% endhighlight %}

これは 0 以上 nTableMask 以下になる.

最初の例のように, 連番をキーに順番に値を挿入した場合は, 各スロットに値が均等に振り分けられる.

しかし, 以下のような値の場合, ひとつのスロットに値が偏る.

{% highlight php %}
<?php
hashtable_dump(array(0 => 1, 8 => 2, 16 => 3, 24 => 4, 32 => 5, 40 => 6, 48 => 7, 56 => 8));
/*
nTableSize:       8
nTableMask:       7
nNumOfElements:   8
nNextFreeElement: 57
pListHead:        0
pListTail:        56
**arBuckets:
  0 => [56, 48, 40, 32, 24, 16, 8, 0, NULL]
  1 => [NULL]
  2 => [NULL]
  3 => [NULL]
  4 => [NULL]
  5 => [NULL]
  6 => [NULL]
  7 => [NULL]
*/
{% endhighlight %}

ハッシュテーブルのスロット数が 8 であれば, キーとして 8 の倍数の要素だけを挿入することで, いずれもハッシュ値が 0 となり, ひとつのスロットに値が集中してしまう.  
ここからキーが 0 の要素を探索する場合, 全ての要素を操作して 8 番目にならないと辿り着けない.  
線形検索をリッチに実装しただけのものになってしまっている.

ここにもうひとつ要素を追加すると次のようになる.

{% highlight php %}
hashtable_dump(array(0 => 1, 8 => 2, 16 => 3, 24 => 4, 32 => 5, 40 => 6, 48 => 7, 56 => 8, 64 => 9));
nTableSize:       16
nTableMask:       15
nNumOfElements:   9
nNextFreeElement: 65
pListHead:        0
pListTail:        64
**arBuckets:
  0 => [64, 48, 32, 16, 0, NULL]
  1 => [NULL]
  2 => [NULL]
  3 => [NULL]
  4 => [NULL]
  5 => [NULL]
  6 => [NULL]
  7 => [NULL]
  8 => [56, 40, 24, 8, NULL]
  9 => [NULL]
  10 => [NULL]
  11 => [NULL]
  12 => [NULL]
  13 => [NULL]
  14 => [NULL]
  15 => [NULL]
{% endhighlight %}

要素数が 9 のときは, テーブルの大きさが 8 の 2 倍の 16 に拡張されるため, 偏りが少し解消される.

以下の関数を使うと, テーブルの拡張も考慮しつつ非効率な HashTable を構築することができる.

{% highlight php %}
<?php
hashtable_dump(hashdos(128));
function hashdos($n) {
    $tableSize = 8;
    while ($tableSize < $n) {
        $tableSize *= 2;
    }
    $arr = array();
    for ($i = 0; $i < $n; $i++) {
        $arr[$tableSize * $i] = NULL;
    }
    return $arr;
}
/*
nTableSize:       128
nTableMask:       127
nNumOfElements:   128
nNextFreeElement: 16257
pListHead:        0
pListTail:        16256
**arBuckets:
  0 => [16256, 16128, 16000, 15872, 15744, 15616, 15488, 15360, 15232, 15104, 14976, 14848, 14720, 14592, 14464, 14336, 14208, 14080, 13952, 13824, 13696, 13568, 13440, 13312, 13184, 13056, 12928, 12800, 12672, 12544, 12416, 12288, 12160, 12032, 11904, 11776, 11648, 11520, 11392, 11264, 11136, 11008, 10880, 10752, 10624, 10496, 10368, 10240, 10112, 9984, 9856, 9728, 9600, 9472, 9344, 9216, 9088, 8960, 8832, 8704, 8576, 8448, 8320, 8192, 8064, 7936, 7808, 7680, 7552, 7424, 7296, 7168, 7040, 6912, 6784, 6656, 6528, 6400, 6272, 6144, 6016, 5888, 5760, 5632, 5504, 5376, 5248, 5120, 4992, 4864, 4736, 4608, 4480, 4352, 4224, 4096, 3968, 3840, 3712, 3584, 3456, 3328, 3200, 3072, 2944, 2816, 2688, 2560, 2432, 2304, 2176, 2048, 1920, 1792, 1664, 1536, 1408, 1280, 1152, 1024, 896, 768, 640, 512, 384, 256, 128, 0, NULL]
  1 => [NULL]
  2 => [NULL]
  3 => [NULL]
  4 => [NULL]
  5 => [NULL]
  6 => [NULL]
  7 => [NULL]
  8 => [NULL]
  9 => [NULL]
  10 => [NULL]
  11 => [NULL]
  12 => [NULL]
  13 => [NULL]
  14 => [NULL]
  15 => [NULL]
  16 => [NULL]
  17 => [NULL]
  18 => [NULL]
  19 => [NULL]
  20 => [NULL]
  21 => [NULL]
  22 => [NULL]
  23 => [NULL]
  24 => [NULL]
  25 => [NULL]
  26 => [NULL]
  27 => [NULL]
  28 => [NULL]
  29 => [NULL]
  30 => [NULL]
  31 => [NULL]
  32 => [NULL]
  33 => [NULL]
  34 => [NULL]
  35 => [NULL]
  36 => [NULL]
  37 => [NULL]
  38 => [NULL]
  39 => [NULL]
  40 => [NULL]
  41 => [NULL]
  42 => [NULL]
  43 => [NULL]
  44 => [NULL]
  45 => [NULL]
  46 => [NULL]
  47 => [NULL]
  48 => [NULL]
  49 => [NULL]
  50 => [NULL]
  51 => [NULL]
  52 => [NULL]
  53 => [NULL]
  54 => [NULL]
  55 => [NULL]
  56 => [NULL]
  57 => [NULL]
  58 => [NULL]
  59 => [NULL]
  60 => [NULL]
  61 => [NULL]
  62 => [NULL]
  63 => [NULL]
  64 => [NULL]
  65 => [NULL]
  66 => [NULL]
  67 => [NULL]
  68 => [NULL]
  69 => [NULL]
  70 => [NULL]
  71 => [NULL]
  72 => [NULL]
  73 => [NULL]
  74 => [NULL]
  75 => [NULL]
  76 => [NULL]
  77 => [NULL]
  78 => [NULL]
  79 => [NULL]
  80 => [NULL]
  81 => [NULL]
  82 => [NULL]
  83 => [NULL]
  84 => [NULL]
  85 => [NULL]
  86 => [NULL]
  87 => [NULL]
  88 => [NULL]
  89 => [NULL]
  90 => [NULL]
  91 => [NULL]
  92 => [NULL]
  93 => [NULL]
  94 => [NULL]
  95 => [NULL]
  96 => [NULL]
  97 => [NULL]
  98 => [NULL]
  99 => [NULL]
  100 => [NULL]
  101 => [NULL]
  102 => [NULL]
  103 => [NULL]
  104 => [NULL]
  105 => [NULL]
  106 => [NULL]
  107 => [NULL]
  108 => [NULL]
  109 => [NULL]
  110 => [NULL]
  111 => [NULL]
  112 => [NULL]
  113 => [NULL]
  114 => [NULL]
  115 => [NULL]
  116 => [NULL]
  117 => [NULL]
  118 => [NULL]
  119 => [NULL]
  120 => [NULL]
  121 => [NULL]
  122 => [NULL]
  123 => [NULL]
  124 => [NULL]
  125 => [NULL]
  126 => [NULL]
  127 => [NULL]
*/
{% endhighlight %}

これを応用すると, HashDoS により効率よく Web サーバを落とすことができてしまう可能性がある.

なぐり書きブログなので特にまとめとかは無い.
