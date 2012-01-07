---
layout: article
title: "PHP の zval を読む #2"
---

今回の記事では GitHub における [php/php-src](https://github.com/php/php-src) の [commit c5d10ddda394b573dfaea1380285e1dd5f3c0d50](https://github.com/php/php-src/tree/c5d10ddda394b573dfaea1380285e1dd5f3c0d50) を前提としている.

前回に引き続き zval 構造体について調べる.  
今回は PHP におけるデータ型について調べて行きたい.

./Zend/zend.h を適当に眺めていると, 以下のような定数があった.

{% highlight cpp %}
#define IS_NULL   0
#define IS_LONG   1
#define IS_DOUBLE 2
#define IS_BOOL   3
#define IS_ARRAY  4
#define IS_OBJECT 5
#define IS_STRING 6
#define IS_RESOURCE 7
#define IS_CONSTANT 8
#define IS_CONSTANT_ARRAY 9
#define IS_CALLABLE 10
{% endhighlight %}

恐らく PHP の基本的なデータ型に対応していると思われる.  
PHP 5.4 なので callable もある.  
CONSTANT_ARRAY というのは何だろう.

とりあえずは IS_ARRAY がどのように使われているか調べてみることにする.

git grep するとたくさん出てくるので, 検索範囲を絞ってみることにする.  
PHP の標準関数の中で, zval や IS_ARRAY がどのように使われてみるか調べてみよう.

標準関数は ./ext/standard ディレクトリ内で定義されている.  
参考: [PHPソースコードリーディング入門(とっかかり編) - id:anatooのブログ](http://d.hatena.ne.jp/anatoo/20111031/1319991834)

./ext/standard/array.c の中を探していると, 以下のような関数が見つかった.

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
        if (mode == COUNT_RECURSIVE) {
            HashPosition pos;

            for (zend_hash_internal_pointer_reset_ex(Z_ARRVAL_P(array), &pos);
                zend_hash_get_current_data_ex(Z_ARRVAL_P(array), (void **) &element, &pos) == SUCCESS;                                                                                                                    zend_hash_move_forward_ex(Z_ARRVAL_P(array), &pos)
            ) {
                Z_ARRVAL_P(array)->nApplyCount++;
                cnt += php_count_recursive(*element, COUNT_RECURSIVE TSRMLS_CC);
                Z_ARRVAL_P(array)->nApplyCount--;
            }
        }
    }

    return cnt;
}
{% endhighlight %}

これは PHP 標準の count() 関数の内部で呼ばれている関数である.  
if (Z_TYPE_P(array) == IS_ARRAY) という記述から, Z_TYPE_P は zval のポインタを渡してその型を調べるためのマクロだと思われる.

Z_TYPE_P は ./Zend/zend_operators.h で定義されていた.

{% highlight cpp %}
#define Z_TYPE(zval)    (zval).type
#define Z_TYPE_P(zval_p)  Z_TYPE(*zval_p)
{% endhighlight %}

Z_TYPE_P が zval のポインタから型を調べるためのマクロで, その内部では zval の値から型を調べる Z_TYPE マクロが呼ばれている.  
そしてこの Z_TYPE マクロは zval の type メンバを読み出してだけである.

というわけで, 前回の記事と総合して, zval の type メンバは PHP におけるデータ型を保持している, ということがわかった.

続く?
