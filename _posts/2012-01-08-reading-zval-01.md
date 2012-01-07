---
layout: article
title: "PHP の zval を読む #1"
---

今回の記事では GitHub における [php/php-src](https://github.com/php/php-src) の [commit c5d10ddda394b573dfaea1380285e1dd5f3c0d50](https://github.com/php/php-src/tree/c5d10ddda394b573dfaea1380285e1dd5f3c0d50) を前提としている.

zval というのは PHP のソースコード中で使用される構造体で, PHP 中で使われる値を持つ汎用的な構造体のようだ.  
PHP のソースコード中には この zval が多数登場する.  
./Zend/zend.h で以下のように定義されている.

{% highlight cpp %}
typedef struct _zval_struct zval;
{% endhighlight %}

{% highlight cpp %}
struct _zval_struct {
  /* Variable information */
  zvalue_value value;   /* value */
  zend_uint refcount__gc;
  zend_uchar type;  /* active type */
  zend_uchar is_ref__gc;
};
{% endhighlight %}

このように, zval は 4 つのメンバから構成されている.  
名前から以下のようなものだと想像される. (あくまで想像である点に注意)

- value: 値それ自体
- refcount__gc: GC に使うリファレンスカウントだろうか
- type: PHP における型
- is_ref__gc: 参照であるかどうか, というフラグだろうか

次に, type メンバの型である zend_uchar について調べてみる.

git grep などで探してみると, ./Zend/zend_types.h に見つかった.

{% highlight cpp %}
typedef unsigned char zend_bool;
typedef unsigned char zend_uchar;
typedef unsigned int zend_uint;
typedef unsigned long zend_ulong;
typedef unsigned short zend_ushort;
{% endhighlight %}

何のことは無い, ただの unsigned char だった.  
その他にもいくつか似たようなものがあり, それぞれそれっぽい型になっているが, zend_bool だけは unsigned char となっている.

次回はもうちょっと PHP のデータ型がどのようになっているか調べよう.
