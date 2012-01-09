---
layout: article
title: "PHP の zval を読む (まとめ)"
---

以下の記事において PHP の zval について調べてきた.

- [PHP の zval を読む #1](/2012/01/08/reading-zval-01.html)
- [PHP の zval を読む #2](/2012/01/08/reading-zval-02.html)
- [PHP の zval を読む #3](/2012/01/08/reading-zval-03.html)

これらを一旦まとめる.

- zval は PHP で使用するデータを格納する構造体である.
- zval には PHP におけるデータ型, 値, そして GC のための情報が格納されている.
- zval.type に型の種類が格納されており, IS_NULL や IS_LONG といった定数との比較で型の確認ができる.
- zval.value には値が格納されている.
- zval.value は zvalue_value 共用体の値が格納されている.
- zvalue_value には数値, 文字列, 配列等のいずれかの型の値が格納されている.
- zval.type から型をチェックし, 例えば IS_ARRAY であれば zval.value.ht を取り出す, などといった処理ができる.

個人的なメモを殴り書くスタンスのブログなので間違いも多分に含まれるとは思いますが, ツッコミなどいただければ幸いです.

次回以降は zvalue_value 共用体の中にある ht メンバの HashTable について調べる.
