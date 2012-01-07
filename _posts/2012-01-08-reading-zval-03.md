---
layout: article
title: "PHP の zval を読む #3"
---

今回の記事でも GitHub における [php/php-src](https://github.com/php/php-src) の [commit c5d10ddda394b573dfaea1380285e1dd5f3c0d50](https://github.com/php/php-src/tree/c5d10ddda394b573dfaea1380285e1dd5f3c0d50) を前提としている.

前回までで大体以下のようなことがわかってきた.

- PHP 中の値はソースコード中では zval という構造体として扱われている
- zval には値, 型, そして GC のためのリファレンスカウントなどが含まれている (ようである)
- zval での型チェックには Z_TYPE_P マクロに zval のポインタを渡して行う
- Z_TYPE_P でのマクロの返り値を IS_NULL や IS_LONG といった定数と比較して, データ型による分岐ができる

ここまで zval の型について調べてきたので, ここからは値, すなわち value メンバについて調べる.  
なお, GC まわりの話は面倒だと思うので一旦避ける予定である.

今回も ./ext/standard/array.c の php_count_recursive 関数を読む.  
PHP の count 関数は本来, 第二引数が COUNT_RECURSIVE なら配列を再帰的に処理するが, こんかいの説明をする上では本質的ではないので, 省略している.

{% highlight cpp %}
static int php_count_recursive(zval *array, long mode TSRMLS_DC)
{
    long cnt = 0;
    zval **element;

    if (Z_TYPE_P(array) == IS_ARRAY) {
        if (Z_ARRVAL_P(array)->nApplyCount > 1) {
            php_error_docref(NULL TSRMLS_CC, E_WARNING, "recursion detected");
            return 0;
        }

        cnt = zend_hash_num_elements(Z_ARRVAL_P(array));
        // mode == COUNT_RECURSIVE 時の処理は省略
    }

    return cnt;
}
{% endhighlight %}

PHP で count に渡された第一引数は, ここでは zval *array となっている.  
例外処理と思われる部分を除けば, 本質的なのはほぼ以下の 1 行だと思われる.

{% highlight cpp %}
cnt = zend_hash_num_elements(Z_ARRVAL_P(array));
{% endhighlight %}

この Z_ARRVAL_P を追ってみよう.  
以下は ./Zend/zend_operators.h から.

{% highlight cpp %}
#define Z_ARRVAL_P(zval_p)    Z_ARRVAL(*zval_p)
{% endhighlight %}

zval_p (元は array) が指す値を Z_ARRVAL に渡し,

{% highlight cpp %}
#define Z_ARRVAL(zval)      (zval).value.ht
{% endhighlight %}

Z_ARRVAL では zval の value メンバ, さらにその中の ht というメンバを読み出している.

value メンバにはどんな値が入っていたのだろうか.  
改めて zval 構造体の定義を ./Zend/zend.h で確認しよう.

{% highlight cpp %}
struct _zval_struct {
  /* Variable information */
  zvalue_value value;   /* value */
  zend_uint refcount__gc;
  zend_uchar type;  /* active type */
  zend_uchar is_ref__gc;
};
{% endhighlight %}

value メンバの型は zvalue_value となっている.  
そしてこの zvalue_value は同じく ./Zend/zend.h で定義されている.

{% highlight cpp %}
typedef union _zvalue_value {
  long lval;          /* long value */
  double dval;        /* double value */
  struct {
    char *val;
    int len;
  } str;
  HashTable *ht;        /* hash table value */
  zend_object_value obj;
} zvalue_value;
{% endhighlight %}

zvalue_value は共用体なので, zval の value メンバには, これらのいずれかが格納されていることになる.  
先の Z_ARRVAL では, zval は配列なので, ht メンバから HashTable という型のポインタを取り出していることになる.

次回は一旦 zval についての簡単なまとめとしようと思う.
