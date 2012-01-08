---
layout: article
title: "PHP の HashTable を読む #1"
---

前回は PHP の zval 構造体についてまとめた.

[PHP の zval を読む (まとめ)](/2012/01/08/reading-zval-wrapping-up.html)

ここからは, zval 構造体の value メンバに配列として格納される HashTable という構造体について調べる.

今回の記事でも GitHub における [php/php-src](https://github.com/php/php-src) の [commit c5d10ddda394b573dfaea1380285e1dd5f3c0d50](https://github.com/php/php-src/tree/c5d10ddda394b573dfaea1380285e1dd5f3c0d50) を前提としている.

HashTable 構造体は ./Zend/zend_hash.h において以下のように定義されている.

{% highlight cpp %}
typedef struct _hashtable {
  uint nTableSize;
  uint nTableMask;
  uint nNumOfElements;
  ulong nNextFreeElement;
  Bucket *pInternalPointer; /* Used for element traversal */
  Bucket *pListHead;
  Bucket *pListTail;
  Bucket **arBuckets;
  dtor_func_t pDestructor;
  zend_bool persistent;
  unsigned char nApplyCount;
  zend_bool bApplyProtection;
#if ZEND_DEBUG
  int inconsistent;
#endif
} HashTable;
{% endhighlight %}

各メンバの名前を観る限りでは, メタデータとしてハッシュテーブルの大きさ, 要素の数などと思われる, 様々な値が格納されているとわかる.

[PHP の zval を読む #3](/2012/01/08/reading-zval-03.html) で読んだ php_count_recursive 関数を再び読んでみよう.  
これは zval 中の配列から要素数を数える関数で, ./ext/standard/array.c で定義されていた.

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

Z_ARRVAL_P マクロが zval のポインタから value, そしてその中の ht メンバを取り出していることも [PHP の zval を読む #3](/2012/01/08/reading-zval-03.html) で読んだ.  
この ht メンバが HashTable 構造体だった.

それでは zend_hash_num_elements 関数を読んでみよう.  
これは ./Zend/zend_hash.c で定義されている.

{% highlight cpp %}
ZEND_API int zend_hash_num_elements(const HashTable *ht)
{
    IS_CONSISTENT(ht);

    return ht->nNumOfElements;
}
{% endhighlight %}

何ということもなく, HashTable 構造体のポインタから nNumOfElements メンバを取り出しているだけである.  
(IS_CONSISTENT マクロはデバッグ用の処理だろうか)

ということで PHP の配列は要素数を持っており, PHP の count 関数の適用時には再計算は行われていない, ということがわかった.  
また, おそらく配列に要素を追加, または削除したときなどは nNumOfElements の値も書き換えられているであろうことが予想される.

次回は配列の操作について調べてみようと思う.
