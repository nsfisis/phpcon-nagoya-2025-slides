PHP 8.4.3 のソースを基に調査



https://php.github.io/php-src/
    https://php.github.io/php-src/core/data-structures/index.html



https://www.phpinternalsbook.com/



https://www.phpinternalsbook.com/php7/zvals/basic_structure.html

zval
    zend_value + type + meta

zend_value
    union
        zend_refcounted*
        zend_string*
        zend_array*
        zend_object*
        zend_reference*


```c
typedef struct _zval_struct     zval;

struct _zval_struct {
	zend_value        value;			/* value */
	union {
		uint32_t type_info;
		struct {
			ZEND_ENDIAN_LOHI_3(
				uint8_t    type,			/* active type */
				uint8_t    type_flags,
				union {
					uint16_t  extra;        /* not further specified */
				} u)
		} v;
	} u1;
	union {
		uint32_t     next;                 /* hash collision chain */
		uint32_t     cache_slot;           /* cache slot (for RECV_INIT) */
		uint32_t     opline_num;           /* opline number (for FAST_CALL) */
		uint32_t     lineno;               /* line number (for ast nodes) */
		uint32_t     num_args;             /* arguments number for EX(This) */
		uint32_t     fe_pos;               /* foreach position */
		uint32_t     fe_iter_idx;          /* foreach iterator index */
		uint32_t     guard;                /* recursion and single property guard */
		uint32_t     constant_flags;       /* constant flags */
		uint32_t     extra;                /* not further specified */
	} u2;
};

typedef union _zend_value {
	zend_long         lval;				/* long value */
	double            dval;				/* double value */
	zend_refcounted  *counted;
	zend_string      *str;
	zend_array       *arr;
	zend_object      *obj;
	zend_resource    *res;
	zend_reference   *ref;
	zend_ast_ref     *ast;
	zval             *zv;
	void             *ptr;
	zend_class_entry *ce;
	zend_function    *func;
	struct {
		uint32_t w1;
		uint32_t w2;
	} ww;
} zend_value;
```

```c
/* Regular data types: Must be in sync with zend_variables.c. */
#define IS_UNDEF					0
#define IS_NULL						1
#define IS_FALSE					2
#define IS_TRUE						3
#define IS_LONG						4
#define IS_DOUBLE					5
#define IS_STRING					6
#define IS_ARRAY					7
#define IS_OBJECT					8
#define IS_RESOURCE					9
#define IS_REFERENCE				10
#define IS_CONSTANT_AST				11 /* Constant expressions */

/* Fake types used only for type hinting.
 * These are allowed to overlap with the types below. */
#define IS_CALLABLE					12
#define IS_ITERABLE					13
#define IS_VOID						14
#define IS_STATIC					15
#define IS_MIXED					16
#define IS_NEVER					17

/* internal types */
#define IS_INDIRECT             	12
#define IS_PTR						13
#define IS_ALIAS_PTR				14
#define _IS_ERROR					15

/* used for casts */
#define _IS_BOOL					18
#define _IS_NUMBER					19


/* zval_gc_flags(zval.value->gc.u.type_info) (common flags) */
#define GC_NOT_COLLECTABLE			(1<<4)
#define GC_PROTECTED                (1<<5) /* used for recursion detection */
#define GC_IMMUTABLE                (1<<6) /* can't be changed in place */
#define GC_PERSISTENT               (1<<7) /* allocated using malloc */
#define GC_PERSISTENT_LOCAL         (1<<8) /* persistent, but thread-local */

#define GC_NULL						(IS_NULL         | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT))
#define GC_STRING					(IS_STRING       | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT))
#define GC_ARRAY					IS_ARRAY
#define GC_OBJECT					IS_OBJECT
#define GC_RESOURCE					(IS_RESOURCE     | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT))
#define GC_REFERENCE				(IS_REFERENCE    | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT))
#define GC_CONSTANT_AST				(IS_CONSTANT_AST | (GC_NOT_COLLECTABLE << GC_FLAGS_SHIFT))

/* zval.u1.v.type_flags */
#define IS_TYPE_REFCOUNTED			(1<<0)
#define IS_TYPE_COLLECTABLE			(1<<1)

/* string flags (zval.value->gc.u.flags) */
#define IS_STR_CLASS_NAME_MAP_PTR   GC_PROTECTED  /* refcount is a map_ptr offset of class_entry */
#define IS_STR_INTERNED				GC_IMMUTABLE  /* interned string */
#define IS_STR_PERSISTENT			GC_PERSISTENT /* allocated using malloc */
#define IS_STR_PERMANENT        	(1<<8)        /* relives request boundary */
#define IS_STR_VALID_UTF8           (1<<9)        /* valid UTF-8 according to PCRE */

/* array flags */
#define IS_ARRAY_IMMUTABLE			GC_IMMUTABLE
#define IS_ARRAY_PERSISTENT			GC_PERSISTENT

/* object flags (zval.value->gc.u.flags) */
#define IS_OBJ_WEAKLY_REFERENCED	GC_PERSISTENT
#define IS_OBJ_DESTRUCTOR_CALLED	(1<<8)
#define IS_OBJ_FREE_CALLED			(1<<9)

/* Recursion protection macros must be used only for arrays and objects */
#define GC_IS_RECURSIVE(p) \
	(GC_FLAGS(p) & GC_PROTECTED)
```






https://www.phpinternalsbook.com/php7/zvals/memory_management.html

zend_refcounted
    refcount
    type_info

文字列や配列は immutable になることがある
    refcount も変化しない
    opcache で共有されるメモリは必ず immutable
        複数のプロセスから参照される
    複数リクエストで使い回すデータは immutable
        並列アクセスされるため
            PHP の refcount は thread-safe でない

persistent allocator と per-request allocator
    persistent allocator
        malloc/free (pemalloc/pefree)
        PHP は関知しない
        リクエスト間で使い回される
        immutable であるか thread-local な領域に確保するかする必要がある
    per-request allocator
        Zend Memory Manager
        リクエストを処理し終わったら破棄される

zval は通常ヒープに確保されない
    ヒープに確保されたより大きなオブジェクトのフィールドとして確保されることはある
        zend_reference はそうだった気がする
    スタックに確保した zval はそのスコープで使い切らなければならない
        引数や返り値を通して by-value で受け渡してはならない
            スコープ外へとコピーされてしまうので

zval そのものは通常共有しない
    zval が内部的に持っている zend_string や zend_array などを共有する
        これらは refcounted

refcount が減ったときにそれがゼロでなければ、サイクルの一部かもしれない
    こういった参照をマークしておいて、GC の root にする

> the structure is marked as potentially circular (the GC_NOT_COLLECTABLE flag is not set)


```c
typedef struct _zend_refcounted zend_refcounted;

struct _zend_refcounted {
	zend_refcounted_h gc;
};

typedef struct _zend_refcounted_h {
	uint32_t         refcount;			/* reference counter 32-bit */
	union {
		uint32_t type_info;
	} u;
} zend_refcounted_h;
```



https://www.phpinternalsbook.com/php7/zvals/references.html



https://www.phpinternalsbook.com/php7/internal_types/strings/zend_strings.html

ハッシュのキャッシュ (h) を持っている
intern することができる
    opcache を使う場合、リクエスト処理の外で intern した文字列はプロセス間やスレッド間で共有される
    IS_STR_PERMANENT フラグが立てられる



https://www.phpinternalsbook.com/php7/extensions_design/php_lifecycle.html

GINIT
    global init
MINIT
    module init
RINIT
    request init
RSHUTDOWN
    request shutdown
RPSHUTDOWN
    request post shutdown
MSHUTDOWN
    module shutdown
GSHUTDOWN
    global shutdown

```
// 前とは名前が変わったらしい
#define PHP_MINIT_FUNCTION		ZEND_MODULE_STARTUP_D
#define PHP_MSHUTDOWN_FUNCTION	ZEND_MODULE_SHUTDOWN_D
#define PHP_RINIT_FUNCTION		ZEND_MODULE_ACTIVATE_D
#define PHP_RSHUTDOWN_FUNCTION	ZEND_MODULE_DEACTIVATE_D
#define PHP_MINFO_FUNCTION		ZEND_MODULE_INFO_D
#define PHP_GINIT_FUNCTION		ZEND_GINIT_FUNCTION
#define PHP_GSHUTDOWN_FUNCTION	ZEND_GSHUTDOWN_FUNCTION
// RPSHUTDOWN はなくなった？
```

CLI は一つのリクエストを処理して終了するという扱い



https://www.phpinternalsbook.com/php7/extensions_design/globals_management.html

リクエスト間で共有される状態をどう管理すればよいか？
    プロセスベースで並列処理をおこなうなら、グローバル変数を使えばよい
    スレッドベースで並列処理をおこなうなら、thread-local 領域に保存する
        コンパイルオプションに応じて自動で切り替えるマクロがある
    初期化したあと参照しかしないならグローバル変数でもよい



https://www.phpinternalsbook.com/php7/memory_management/zend_memory_manager.html

Zend Memory Manager (ZendMM; ZMM) は per-requset な allocator
    emalloc/efree
    memory_limit の監視もおこなう
        persistent allocator (malloc/free) によって管理される領域は関知しない

shared-nothing アーキテクチャ
    リクエスト間で共有されるデータが (ほとんど) ない

heap
chunk
map
page
bin
huge_list
    説明しない




zend_gc.c

* BLACK  (GC_BLACK)   - In use or free.
    GC の対象外
* GREY   (GC_GREY)    - Possible member of cycle.
    サイクルの可能性あり
* WHITE  (GC_WHITE)   - Member of garbage cycle.
    ゴミサイクルの一部
* PURPLE (GC_PURPLE)  - Possible root of cycle.
    サイクルの起点の可能性あり

gc_mark_roots からスタート
    possible roots を traverse
    purple なオブジェクトに対して DFS、mark_grey を呼び出していく

gc_scan_roots
    各 root に対して gc_scan を呼ぶ
        grey で refcount > 0
            gc_scan_black を呼ぶ
                解放できるかもしれないと思ったが、使用中なので解放できないことがわかった
                => 子も含めて black で塗り直す
        grey で refcount = 0
            white としてマーク (ゴミ確定)

A node MAY be added to possible roots when ZEND_UNSET_VAR happens or
zend_assign_to_variable is called only when possible garbage node is
produced.
gc_possible_root() will be called to add the nodes to possible roots.



zend_gc_collect_cycles
    gc_mark_roots
    gc_scan_roots
    gc_collect_roots
    gc_compact



gc_mark_roots
    すべての purple な roots に対して、
        grey にする
        gc_mark_grey を呼び出す

gc_mark_grey
    すべての子に対して、
        refounct を 1減らす
        grey でなければ grey で塗る

gc_scan_roots
    すべての grey な roots に対して、
        white にする
        gc_scan を呼び出す

gc_scan
    自身が white でなければ終わり
    refcount > 0 なら自身を black にして gc_scan_black を呼ぶ
    refcount = 0 なら子をチェックして、grey だったら white に

gc_scan_black
    refcount を 1増やして再帰的に black に

gc_collect_roots
    black な roots を root buffer から消す
    すべての white な roots に対して
        black にする
        gc_collect_white を呼ぶ

gc_collect_white
    自身を garbage とマーク
    すべての子に対して、
        refcount を 1増やす
        white なら black にする

gc_compact
    Two-finger compaction algorithm
    いわゆる「コンパクション」ではなく、GC の root objects を貯めておくバッファをコンパクションしている
    先頭に使っている root objects を持ってきて、後ろに未使用 objects を持っていく




zend_gc_collect_cycles が呼ばれるタイミング
    gc_possible_root_when_full から (だけ)
    あとは PHP レベルで gc_collect_cycles() を呼んだときだけ

gc_possible_root_when_full は gc_possible_root からだけ呼ばれる
    root buffer が一杯になったときだけ解放処理が走る

gc_possible_root が呼ばれるタイミング
    gc_check_possible_root
    gc_check_possible_root_no_ref
    zend_object_release
        refcount を減らしたときに 0 でなければ root かもしれない
        ただし GC_NOT_COLLECTABLE フラグが立っていないオブジェクトに限る
    Zend/zend_vm_def.h / Zend/zend_vm_execute.h / ext/opcache/jit/zend_jit_ir.c にもあるが追うのが難しそう
        assign したときの元の値に対して refcount を減らしてみて、0 でないなら root かもしれない
            実質的にやっていることは zend_object_release と同一に見える


* zend_refcounted を持っている構造体には何がある？
    * zend_string
    * zend_array
    * zend_object
    * zend_resource
    * zend_reference




弱参照
    #define IS_OBJ_WEAKLY_REFERENCED	GC_PERSISTENT
    Zend/zend_weakrefs.c
    グローバルに weakrefs という辞書を持っていて、object のポインタから WeakReference へ変換する
    zend_weakrefs_notify
        弱参照されているオブジェクト側にフラグを立てておいて、フラグが立っていれば dtor からこれを呼ぶ
        そのオブジェクトを参照していた weakref は無効になる




* GC 関係のフラグ
    * GC_NOT_COLLECTABLE
        * refcounted ではあるが、絶対に cycle の一部ではない
            * string
            * resource
            * reference
    * GC_PROTECTED
        * used for recursion detection
        * var_dump で再帰的な構造をダンプしたときとかに使われるらしい
        * GC_PROTECT_RECURSION
            * array_walk_recursive とかでも使われている
    * GC_IMMUTABLE
        * can't be changed in place
        * プロセス or スレッド間で共有 (opcache)
    * GC_PERSISTENT
        * allocated using malloc()
    * GC_PERSISTENT_LOCAL
        * persistent, but thread-local





一度 root buffer に入って、あとから (循環参照ではなかったために) 消えた場合どうなる？
    gc_remove_from_roots
    gc_remove_from_buffer
    GC_REMOVE_FROM_BUFFER
        使っている tmpvar は除外されるっぽい
    gc_remove_nested_data_from_buffer
    消す処理自体はあるが、これらを解放処理のたびに呼んでいるわけではなさそうな気がする
        再利用された場合は、少なくとも purple ではなくなるからいいのかな？
        gc_collect_roots で black な root は消される
            初期状態は black (数値としては 0) なはず




root buffer のサイズ、今の実装だと可変っぽい

```c
#define GC_DEFAULT_BUF_SIZE  (16 * 1024)        // 16k
#define GC_BUF_GROW_STEP     (128 * 1024)       // 128k
#define GC_MAX_UNCOMPRESSED  (512 * 1024)       // 512k
#define GC_MAX_BUF_SIZE      0x40000000         // 1024M
#define GC_THRESHOLD_DEFAULT (10000 + GC_FIRST_ROOT)
#define GC_THRESHOLD_STEP    10000
#define GC_THRESHOLD_MAX     1000000000
#define GC_THRESHOLD_TRIGGER 100

gc_adjust_threshold
/* TODO Very simple heuristic for dynamic GC buffer resizing:
 * If there are "too few" collections, increase the collection threshold
 * by a fixed step */
```

あまり回収されなかったら閾値を上げる、回収量が大ければ閾値を下げる









# プロポーザル

## PHP 処理系の garbage collection を理解する 〜メモリはいつ解放されるのか〜

Garbage collection (GC) とは、確保したメモリ領域を適切なタイミングで解放する仕組みのことです。
メモリが比較的潤沢になった今でも、メモリ溢れによるサーバ障害は決して珍しくありません。
PHP における GC を理解し、メモリを意識したプログラミングをすることで、本番サーバを夜中に落とさないようにしましょう。

### 主な対象

* 普段メモリを意識してプログラミングしていないかた
* 言語処理系の内部実装に興味があるかた
* メモリ溢れで本番環境をダウンさせたことのあるかた

### 話すこと

* PHP における GC のアルゴリズム
* 確保したメモリはいつ解放されるのか
* メモリ溢れを起こさないプログラミング

### 話さないこと

* GC のパラメータをいじってチューニングする






# 構成

* 前提知識
    * メモリとは
        * 知っている前提で軽く流す
    * メモリ管理
* なぜメモリ管理が重要なのか
    * メモリが潤沢な時代でも...
        * メモリは無限ではない
        * 速度の話は要る？
    * メモリについて何も考えていないと起こること
        * スラッシング
* メモリ管理
    * 確保と解放
    * GC のモチベーション
        * メモリリーク・セグフォ
* PHP の GC
    * 一言で
    * 参照カウント
    * 循環参照
    * Mark & sweep
    * 具体的な型では？
    * CoW
    * イミュータブル・共有
    * リクエストバウンドかそれ以外か
    * memory_limit
    * Zend Memory Manager
    * 解放のトリガー
    * デストラクタ
    * 参照
    * fclose()
    * GC を制御するパラメータの意味
    * 弱参照
* メモリを溢れさせないために
    * 載らない量を載せない
    * 一度に扱う量を減らす
* まとめ
* Q&A
