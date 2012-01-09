---
layout: article
title: "PHP の HashTable を読む #2"
---
今回の記事でも GitHub における [php/php-src](https://github.com/php/php-src) の [commit c5d10ddda394b573dfaea1380285e1dd5f3c0d50](https://github.com/php/php-src/tree/c5d10ddda394b573dfaea1380285e1dd5f3c0d50) を前提としている.

前回は HashTable 構造体には nNumOfElements というメンバがあり, PHP の count 関数ではその値を読んでいることがわかった.  
つまり, 配列の要素数が変わるタイミングで, nNumOfElements の値は書き変わるはずだ.  
今回はその辺りに付いて読んでみる.

./Zend/zend_hash.c の中に, 以下のような関数を見つけた.

{% highlight cpp %}
ZEND_API int _zend_hash_init(HashTable *ht, uint nSize, hash_func_t pHashFunction, dtor_func_t pDestructor, zend_bool persistent ZEND_FILE_LINE_DC)
{
    uint i = 3;

    SET_INCONSISTENT(HT_OK);

    if (nSize >= 0x80000000) {
        /* prevent overflow */
        ht->nTableSize = 0x80000000;
    } else {
        while ((1U << i) < nSize) {
            i++;
        }
        ht->nTableSize = 1 << i;
    }

    ht->nTableMask = 0; /* 0 means that ht->arBuckets is uninitialized */
    ht->pDestructor = pDestructor;
    ht->arBuckets = (Bucket**)&uninitialized_bucket;
    ht->pListHead = NULL;
    ht->pListTail = NULL;
    ht->nNumOfElements = 0;
    ht->nNextFreeElement = 0;
    ht->pInternalPointer = NULL;
    ht->persistent = persistent;
    ht->nApplyCount = 0;
    ht->bApplyProtection = 1;
    return SUCCESS;
}
{% endhighlight %}

恐らく PHP の array データを初期化しているものと思われる.  
nTableSize メンバには HashTable の大きさと思われる値が代入されており, 0x80000000 は超えないようにされている.

そのあとはパラメータや定数をそのまま代入しているだけだ.

配列の初期化時点では空なので, 当然 nNumOfElements は 0 だ.

nNextFreeElement も 0 となっているが, これは PHP で $arr\[\] = "foo" などとしたときに暗黙的に指定されるキーだろうか.

また, pListHead や pListTail のような, リスト要素を指すメンバにも当然のごとく NULL で初期化されている.

そして, pInternalPointer は, ./Zend/zend_hash.h の HashTable 構造体を定義している箇所のコメントによると, Used for element traversal とされている.  
恐らく foreach などで array を走査するときに, 現在の要素を保持しておくためのものだろうか.

これらのメンバが配列操作時にどのように扱われているか, 見ていこう.  
./Zend/zend_hash.c に _zend_hash_index_update_or_next_insert という関数がある.  
いかにも $arr\[0\] = "foo" といった操作時に呼ばれてそうだ.

grep してもあまりヒットしないが, ./Zend/zend_hash.h 上にこのようなマクロがあった.

{% highlight cpp %}
ZEND_API int _zend_hash_index_update_or_next_insert(HashTable *ht, ulong h, void *pData, uint nDataSize, void **pDest, int flag ZEND_FILE_LINE_DC);
#define zend_hash_index_update(ht, h, pData, nDataSize, pDest) \
    _zend_hash_index_update_or_next_insert(ht, h, pData, nDataSize, pDest, HASH_UPDATE ZEND_FILE_LINE_CC)
#define zend_hash_next_index_insert(ht, pData, nDataSize, pDest) \
    _zend_hash_index_update_or_next_insert(ht, 0, pData, nDataSize, pDest, HASH_NEXT_INSERT ZEND_FILE_LINE_CC)
{% endhighlight %}

(ht, h, pData, nDataSize, pDest, HASH_UPDATE ZEND_FILE_LINE_CC)
(ht, 0, pData, nDataSize, pDest, HASH_NEXT_INSERT ZEND_FILE_LINE_CC)

