---
layout: article
title: "PHP の HashTable を読む #2"
---
今回の記事でも GitHub における [php/php-src](https://github.com/php/php-src) の [commit c5d10ddda394b573dfaea1380285e1dd5f3c0d50](https://github.com/php/php-src/tree/c5d10ddda394b573dfaea1380285e1dd5f3c0d50) を前提としている.

前回は HashTable 構造体には nNumOfElements というメンバがあり, PHP の count 関数ではその値を読んでいることがわかった.  
つまり, 配列の要素数が変わるタイミングで, nNumOfElements の値は書き変わるはずだ.  
今回はその辺りに付いて読んでみる.

./Zend/zend_hash.c の中に, 以下のようなマクロ, 関数を見つけた.

{% highlight cpp %}
#define zend_hash_init(ht, nSize, pHashFunction, pDestructor, persistent)           _zend_hash_init((ht), (nSize), (pHashFunction), (pDestructor), (persistent) ZEND_FILE_LINE_CC)
{% endhighlight %}

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

_zend_hash_init のパラメータの最後についている ZEND_FILE_LINE_DC はソースコードのファイル名, 行数を引数として渡すマクロのようだ.  
デバッグ時のみ渡されるようになるが, zend_hash_init マクロを呼ぶ限りは, そういったことは意識する必要が無い.  
./Zend/zend.h で定義されている.

{% highlight cpp %}
/* 一部略している */
#if ZEND_DEBUG
#define ZEND_FILE_LINE_D        const char *__zend_filename, const uint __zend_lineno
#define ZEND_FILE_LINE_DC       , ZEND_FILE_LINE_D
#define ZEND_FILE_LINE_C        __FILE__, __LINE__
#define ZEND_FILE_LINE_CC       , ZEND_FILE_LINE_C
#else
#define ZEND_FILE_LINE_D
#define ZEND_FILE_LINE_DC
#define ZEND_FILE_LINE_C
#define ZEND_FILE_LINE_CC
#endif  /* ZEND_DEBUG */
{% endhighlight %}

zend_hash_init はその名前からすると, HashTable の初期化に使用するものだと思われる.  
nTableSize メンバには HashTable の大きさと思われる値が代入されており, 0x80000000 は超えないようにされている.

そのあとはパラメータや定数をそのまま代入しているだけだ.  
ただし, pHashFunction は特にどのメンバにもセットされておらず, 使われていないようだ.  
zend_hash_init が呼ばれている箇所を grep してみても, どれも NULL を渡しているようだ.

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

zend_hash_index_update も zend_hash_next_index_insert も _zend_hash_index_update_or_next_insert を呼んでおり, それぞれのマクロは以下の点において違うようだ.

- zend_hash_next_index_insert では関数に渡す第二引数の指定はできず, 常に 0 が渡るようになっている.
- フラグとして HASH_UPDATE か HASH_NEXT_INSERT が渡されている.

_zend_hash_index_update_or_next_insert 関数を見てみよう.  
日本語のコメントは全て私が書き込んだものだ.

{% highlight cpp %}
ZEND_API int _zend_hash_index_update_or_next_insert(HashTable *ht, ulong h, void *pData, uint nDataSize, void **pDest, int flag ZEND_FILE_LINE_DC)
{
    uint nIndex;
    Bucket *p;
#ifdef ZEND_SIGNALS
    TSRMLS_FETCH();
#endif

    IS_CONSISTENT(ht);
    CHECK_INIT(ht);

    /**
     * flag が「次に挿入」モードであれば,
     * HashTable の次の空き要素を使用する.
     */
    if (flag & HASH_NEXT_INSERT) {
        h = ht->nNextFreeElement;
    }
    nIndex = h & ht->nTableMask;

    p = ht->arBuckets[nIndex];
    while (p != NULL) {
        /**
         * nKeyLength が 0 のとき, つまり数値がキーである場合.
         * そして, キーとして指定した h 番目の要素を探している.
         */
        if ((p->nKeyLength == 0) && (p->h == h)) {
            /**
             * 次への挿入, または追加モードのとき,
             * 既にそのキーが存在すればエラー.
             */
            if (flag & HASH_NEXT_INSERT || flag & HASH_ADD) {
                return FAILURE;
            }
            HANDLE_BLOCK_INTERRUPTIONS();
#if ZEND_DEBUG
            if (p->pData == pData) {
                ZEND_PUTS("Fatal error in zend_hash_index_update: p->pData == pData\n");
                HANDLE_UNBLOCK_INTERRUPTIONS();
                return FAILURE;
            }
#endif
            /**
             * 更新モードのときは, 既にあった要素内の値のみを,
             * HashTable に指定されたデストラクタで開放する.
             */
            if (ht->pDestructor) {
                ht->pDestructor(p->pData);
            }
            UPDATE_DATA(ht, p, pData, nDataSize);
            HANDLE_UNBLOCK_INTERRUPTIONS();
            if ((long)h >= (long)ht->nNextFreeElement) {
                ht->nNextFreeElement = h < LONG_MAX ? h + 1 : LONG_MAX;
            }
            if (pDest) {
                *pDest = p->pData;
            }
            /* 既存の要素を更新した場合はここで終了. */
            return SUCCESS;
        }
        /* 連結リストの次を辿る. */
        p = p->pNext;
    }
    /* 新しく挿入する場合, ここで新しい要素として Bucket を生成する. */
    p = (Bucket *) pemalloc_rel(sizeof(Bucket), ht->persistent);
    if (!p) {
        return FAILURE;
    }
    p->arKey = NULL;
    p->nKeyLength = 0; /* Numeric indices are marked by making the nKeyLength == 0 */
    /* Bucket は自分が何番目の要素であるかを知っている. */
    p->h = h;
    INIT_DATA(ht, p, pData, nDataSize);
    if (pDest) {
        *pDest = p->pData;
    }

    /* 双方向リストを更新する. */
    CONNECT_TO_BUCKET_DLLIST(p, ht->arBuckets[nIndex]);

    HANDLE_BLOCK_INTERRUPTIONS();
    /* HashTable 内の配列に新たに生成した Bucket を追加. */
    ht->arBuckets[nIndex] = p;
    CONNECT_TO_GLOBAL_DLLIST(p, ht);
    HANDLE_UNBLOCK_INTERRUPTIONS();

    /* 次の空き要素として, 今追加した要素の次を指定する. */
    if ((long)h >= (long)ht->nNextFreeElement) {
        ht->nNextFreeElement = h < LONG_MAX ? h + 1 : LONG_MAX;
    }
    /* 要素を新規に挿入したので, HashTable の要素数を同期する. */
    ht->nNumOfElements++;
    ZEND_HASH_IF_FULL_DO_RESIZE(ht);
    return SUCCESS;
}
{% endhighlight %}

HashTable の arBuckets という配列に, 新しく生成した値をセットしつつ, 双方向リストとしても整合を取るよう, CONNECT_TO_BUCKET_DLLIST マクロを呼んでいる.  
CONNECT_TO_BUCKET_DLLIST は ./Zend/zend_hash.c で定義されている.

{% highlight cpp %}
#define CONNECT_TO_BUCKET_DLLIST(element, list_head)        \
    (element)->pNext = (list_head);                         \
    (element)->pLast = NULL;                                \
    if ((element)->pNext) {                                 \
        (element)->pNext->pLast = (element);                \
    }
{% endhighlight %}

異常から大体以下のようなことがわかった.

- HashTable はその要素として Bucket 構造体を指すポインタの配列を持つ.
- Bucket は双方向リストとして各要素が連結されている.
- HashTable を追加したタイミングで, その要素数や, 次の空き要素の位置が更新される.

次は Bucket 構造体についてでも読んでみようと思う.
