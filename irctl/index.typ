#!/bin/env -S typst watch
#import "buhou-tmpl.typ":main
#import "@preview/zebra:0.1.0":qrcode
#import "@preview/codly:1.3.0":*
#import "@preview/codly-languages:0.1.10":*
#show: codly-init.with()
#codly(languages:codly-languages)
#show raw.line:it=>{show regex("\S"):it=>sym.zws+it;it}

#show:main.with(
	no:80,
	title:[modernAVRで赤外線リモコン],
	author:[22 McbeEringi],
	brief:[
		身の回りの赤外線リモコン、\
		「もうひとつあれば……」「こんなボタンがあれば……」\
		「使わないボタンで大きい」「元のスイッチを切ってしまう」\
		そんな悩みはありませんか?\
		理想のリモコンを設計してみました
	],
)

= 動機
自室のシーリングライトのリモコンをArduino IRRemote ライブラリで解析した。
単純な機器の割に含まれるデータ量が多すぎて興味が失せてしまった。

そんな矢先、シーリングライトが寿命を迎えた。
これは絶好のチャンスとのことでハックし易そうな品を購入した。
まずはそのリモコンを見ていただきたい。

#figure(
image("hotalux.jpg"),
caption:[新しいシーリングライトのリモコン]
)

中央のボタンには「点灯 常夜灯 OFF」と書かれている。
独立した常夜灯ボタンが存在しない。

#colbreak()

深夜に少し物を取りに行きたい場面を想像してほしい。
常夜灯をつけたい。
やむなく中央のボタンを押す。
瞬間、灯る爆光、白く染まる視界……

もうこんな生活は嫌だ。


= 赤外線リモコンについて
赤外線、可視光と同じく身の回りに満ち溢れている。
ここに情報をのせて識別可能にする、確実に伝達する。そのために、それ相応の工夫がなされている。
== 変調
赤外線リモコンでは波長950nmの赤外線がよく用いられる。
さらに他の赤外線と区別がつくように特定の周波数で変調されている。
一般的に38kHzで変調されており、フォトトランジスタの後段に設けたバンドパスフィルタで目的の信号のみが分離される。
市販されている赤外線受光モジュールは、フォトトランジスタ、アンプ、バンドパスフィルタが一体となったものである。
== プロトコル
変調する前段階の信号をどう組み立てるか。
一般に流通している製品では、3通りのプロトコルのうちどれかが使われていることが多い。

これについては以下のサイトに良く纏められているので是非こちらを参照してほしい。

#figure(
qrcode("https://elm-chan.org/docs/ir_format.html"),
caption:[https://elm-chan.org/docs/ir_format.html]
)

AVRと言えば、組み込みでFatFsと言えば、の、あのelm-chan氏のサイトである。
私が語ったところで、このサイト以上の情報は出てこない。

以下、重要な情報だけ抜粋する。

=== NECフォーマット
- 変調単位 562us
- カスタマーコード 16bit
- データ 8bit + 8bit パリティ

パリティは単にデータのNOTを取ったものである。
カスタマーコードのエラーは検出できない。(する必要がない)
ものによってはエラー検出の領域も合わせてデータ領域として使われている。

送信するデータが少ない場合はこれで十分そう。

動機の章で述べた「ハックしやすい」というのは、このフォーマットを採用してるということである。
NECの息の掛かった企業ならNECフォーマットだろうと踏んで購入した。

=== 家製協フォーマット
- 変調単位 425us
- カスタマーコード 16bit + 4bit パリティ
- データ 4+8Nbit

データが可変長なのが特徴。
NECフォーマットだと物足りない場合はこっち。

動機の章で述べた「単純な機器の割に含まれるデータ量が多すぎて」というのは、このフォーマットを採用していたということである。

=== SONYフォーマット
- 変調単位 600us
- データ 7bit
- アドレス 5/8/13bit

これだけ40kHzで変調されるが、38kHzの受信機で問題なく受信できた。
SONY専用なのでカスタマーコードが存在しない。
アドレス部分は対象の機器の役割で振られており、テレビ、ビデオカメラといった具合である。
我が屋のテレビで試したところ同じ信号を4回送信しないと反応しなかった。
パリティが一切存在しない代償なのだろう。

= ハードウェア
ハードウェアとソフトウェアは同時進行で製作したが、説明が別々にできるほどには互いに依存しない作りなので別々に説明する。
== 試作
=== 製作

手許にあった以下の部品でまずは試作をした
- modernAVR ATTiny202
- 砲弾型赤外線LED OSI5LA5113A
- フラット赤外線LED OSI5LA7WA1B
- Nch FET IRLML6344TRPBFTR
- Nch FET BSS138
- MLCC 100u
- MLCC 4.7u
- ボタン SKRGAAD010
- CR2032ホルダー
- D基板

マイコンはmodernAVR代表ATTiny202を採用した。
代表とここで呼んでいるのは、秋月で取扱われた最初のmodernAVR(tiny)であるから。
最大の理由は使い慣れていること。
スリープを使うことで駆動時間を大きく伸ばすことができる。
スリープ中の電力の計算をしたところ、CR2032の自己放電の方が大きかった。

赤外線LEDはピンソケットに差すことで、交換可能な作りにした。
複数のLEDを交換して比較できる。

赤外線LEDの駆動のためにFETを挟んだ。
赤外線リモコンにおいては定格を大きく上回る電流を流すことが一般的らしい。
大きめのコンデンサを手前に挟んでパルスで大電流を流すことで送信距離を伸ばすことができる。
許容電流の大きなIRLML6344TRPBFTRと信号用の汎用品BSS138をコンデンサの容量とあわせて比較した。

ボタンと電池ホルダー、基板は有り合せのものを使った。
書き込み用にGNDとUPDIをピンソケットで引き出してある。

#figure(
image("first.jpg"),
caption:[試作機]
)

写真今日撮ったもの。
製作当初は2ボタンだった。

=== 検証

LEDについて、普通の砲弾型のLEDでは指向性が強すぎて操作対象を狙う必要があった。
砲弾型の半減角が15°であるのに対し、フラットなLEDは100°とかなり広範囲に赤外線を飛ばせる。
これに交換したところ、向いている方向に関係なく反応するようになった。

FETとMLCCの容量について、送信距離に特段の差は感じなかった。
差が出たのは電池持ちだった。
IRLML6344TRPBFTRの場合、数週間で電池が切れた。
100uFは4.7uFに比べて若干電池が早く切れたような記憶がある。
BSS138では未だ電池の切れる気配がない。

原因は分かっていない。
それぞれのFETのゲート容量は、IRLML6344TRPBFTRが650pF、BSS138が50pFと、確かに桁が違うがまさか、と思っている。

== 小型版

=== 製作

枕元に固定されたリモコンがあれば便利そうだということで、
ここで邪魔にならない程度に小さなリモコンを製作した。
部品は試作での検証を踏まえた同一の構成である。
唯一基板だけをサイズ半分のE基板に変更した。
ボタン電池は基板裏面に配置されており、配線には少々気を遣った。
ボタンは上から、点灯/常夜灯/OFF、常夜灯、OFF に割り当てた。
常夜灯もOFFも純正のリモコンに専用のボタンは存在しないが、これについてはソフトウェアの章で説明する。

#figure(
image("mini.jpg"),
caption:[枕元の窓枠に固定された小型版]
)

=== 検証
かれこれ一年間使い続けているが未だ電池が切れていない。
全く問題なく機能している。

== PCB
=== 製作
これ以上洗練された設計はユニバーサル基板では難しいのでPCBを設計することにした。
LEDが基板から飛び出さない設計にした。
LEDの下の銅箔を剥き出しにすることで手前側に赤外線が反射するようにした。
ケースに収めることを前提に左右に余白を設け、裏面はなるべく配線を通さないようにした。

#place(
	auto,
	scope:"parent",
	float:true,
	figure(
		image("4btn.png"),
		caption:[PCBリモコンの設計]
	)
)


#figure(
qrcode("https://github.com/McbeEringi/pcb-stuff/tree/main/proj/ir_remote/4btn"),
caption:[https://github.com/McbeEringi/pcb-stuff/tree/main/proj/ir_remote/4btn]
)

=== 検証
回路やソフトウェア自体は問題なく動作した。

ボタンのすぐ隣にLEDを配置たことで、ボタンを押す指の影に隠れて機器が反応しないことがあった。
LEDはボタンからは少し離れた位置に配置するべきだった。

#figure(
image("4btn.jpg"),
caption:[壁に固定されたPCBリモコン]
)


== 壁スイッチリモコン
=== 動機

いくら優秀なリモコンを設計したとて、壁スイッチを切られてしまっては為す術が無い。
これを防ぐアイテムとして壁スイッチカバーが百均等で市販されている。
しかし壁スイッチカバーはスイッチに接続された機器を操作したい人の前では無力である。
そのような人はカバーを外してスイッチを操作する。

では壁スイッチカバー自体にリモコンの機能を持たせてしまえば良いのでは?

=== 製作
基本的な設計はこれまで同様である。

より確実に機器を反応させるため、LEDを3発直列で用いることにした。
CR2032一つでは電圧が不足するため、これも2つ直列で用いる。
しかし今度はAVRの最大電圧を超過してしまう。
2つ直列にした電池の中間から3Vを取り出すことでAVRの電源を確保した。

まずはユニバーサル基板で試作した。
プリント品のカバーと基板は、これまたプリント品の板バネで接続されている。
#figure(
	image("kabe_proto.jpg"),
	caption:[ユニバーサル基板で試作]
)

コンセプトとして動くことは分かったのでPCBに起こした。

コスモワイド21の化粧板を置換するために寸法を合わせた。
表面の模様も銅箔を剥き出して再現した。
LEDだけを表側に配置し、その他の部品は壁スイッチ内部の部品に干渉しないように配慮しつつ裏面に配置した。
ボタンは1つのみで、押された際にスイッチ取付枠に押されるように端に配置した。
固定用のM3のネジ穴も念のため用意した。


#place(
	auto,
	scope:"parent",
	float:true,
	figure(
		image("wall.png"),
		caption:[壁スイッチリモコンの設計]
	)
)
#figure(
qrcode("https://github.com/McbeEringi/pcb-stuff/tree/main/proj/ir_remote/cosmo_wide21"),
caption:[https://github.com/McbeEringi/pcb-stuff/tree/main/proj/ir_remote/cosmo_wide21]
)

=== 検証

とりあえずでマスキングテープで固定したら、あまりにも問題なく使えてしまった。
固定用の治具を3Dプリントする予定だったが、未だ設計はしていない。

壁スイッチをカバーしつつリモコンとして動作させる目的は達成された。
うっかり壁スイッチを操作してもこれで大丈夫。

#figure(
image("wall.jpg"),
caption:[壁スイッチの化粧板から交換された壁スイッチリモコン]
)
#figure(
image("wall_back.jpg"),
caption:[裏面の部品]
)

= ソフトウェア
成果物はこちら。
#figure(
	qrcode("https://github.com/McbeEringi/avr-stuff/tree/main/ir_remote"),
	caption:[https://github.com/McbeEringi/avr-stuff/tree/main/ir_remote]
)
== まずは動くものを
まずは純正リモコンの信号をArduino IRRemoteで読み取ることから始めた。
すぐにNECフォーマットであること、データ本体は8bitであることが分かった。

以前電子オルゴールのプログラムを組んだ。
これは80kHzに可聴域の周波数成分を載せる作りで、38kHzに信号を載せる赤外線リモコンに流用するにはぴったりだった。
まずは動くコードを用意した。

```c
/*
IR: tX02 ? PA2 : PB2
LED: PA3
SW : PA7
*/

#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>

#define CODE 0x41b6fd02

#define BTN_DOWN ~VPORTA.IN&(1<<7)
#define FOR(X) for(uint8_t i=0;i<X;i++)
#define IR_ON TCA0.SINGLE.CMP2BUF=10// 35/3-1
#define IR_OFF TCA0.SINGLE.CMP2BUF=0
void wait(){while(!(TCB0.INTFLAGS&TCB_CAPT_bm));TCB0.INTFLAGS=1;}// TCB0 561.75us
void wait_btn(){while(BTN_DOWN)FOR(18)wait();}// 0.56175*18=10.1115ms

void sleep(){sei();SLPCTRL.CTRLA=SLPCTRL_SMODE_PDOWN_gc|SLPCTRL_SEN_bm;sleep_cpu();cli();}
ISR(PORTA_PORT_vect){PORTA.INTFLAGS=PORT_INT7_bm;}

static void blink(uint8_t x){FOR(8){if((x>>i)&1)PORTA.OUTSET=0b1000;else PORTA.OUTCLR=0b1000;FOR(111)wait();}}// LSB first 1/16s * 8

static void send(uint32_t x){
	IR_ON;FOR(16)wait();
	IR_OFF;FOR(8)wait();
	FOR(32){
		IR_ON;wait();IR_OFF;wait();
		if(x>>(31-i)&1){wait();wait();}
	}
	IR_ON;wait();IR_OFF;
}

void main(){
	// TCA0 IR 1333kHz/35=38.095kHz
	TCA0.SINGLE.CTRLA=TCA_SINGLE_ENABLE_bm;// 分周無し TCA有効
	TCA0.SINGLE.CTRLB=TCA_SINGLE_CMP2EN_bm|TCA_SINGLE_WGMODE_SINGLESLOPE_gc;// TCA0 wo2有効 単傾斜PWM
	TCA0.SINGLE.PER=34;// TOP 35-1

	// TCB0 delay 1333kHz/749=1780.151Hz=561.75us
	TCB0.CTRLA=TCB_ENABLE_bm;// 分周無し TCB有効
	TCB0.CCMP=748;// TOP=F_CPU/1780=(749.333-1)

	_PROTECTED_WRITE(CLKCTRL.MCLKCTRLB,CLKCTRL_PDIV_12X_gc|CLKCTRL_PEN_bm);// 12分周 CLR_PER=16M/12=1333k Hz
	#ifdef USE_PB2
		PORTA.DIRSET=0b1000;// 出力: PA3
		PORTB.DIRSET=0b0100;// 出力: PB2
	#else
		PORTA.DIRSET=0b1100;// 出力: PA2,3
	#endif
	PORTA.PIN7CTRL=PORT_PULLUPEN_bm|PORT_ISC_LEVEL_gc;// PA7 プルアップ BOTHEDGESかLEVEL

	blink(0b01010101);
	while(1){sleep();send(CODE);blink(0b00110011);wait_btn();}
}
```

TCA0で38kHz、TCB0で562usを刻む作りである。
計算すると1.3MHzで精度良く信号を生成できる。
既にスリープも実装されていて省電力なコードなのだ。

== 隠しコードの発見

NECのシーリングライトのリモコンを解析している人をネット上で数人発見した。
それを眺めているとなんと解析で得た手許のコードと一致したのである。

そしてそのサイトには常夜灯のコードが記載されていた。
これを試しに送ったところ、常夜灯がついてしまったのである!!

他にも隠しコードがあると直感した私は、周辺を総当たりするプログラムをこさえた。
結果、点灯、消灯のコードを発見した。

#codly(offset:9)
```c
// NEC Hotalux RE0212 (HLDC08301SG 付属)
const uint8_t nec_re_x[]={0x82,0x6d,
	// .+:ボタン名, .+!:反応あり, -:反応なし, --.+--:参考文献より引用 <https://shrkn65.nobody.jp/remocon/database.html>
	// TODO: リモコン設定用信号(中央3秒)
	//0xa0,0x5f// -
	//0xa1,0x5e// -
	//0xa2,0x5d// 点灯!
	//0xa3,0x5c// -
	//0xa4,0x5b// -
	//0xa5,0x5a// -
	//0xa6,0x59// 全灯
	//0xa7,0x58// 白色
	//0xa8,0x57// 暖色
	//0xa9,0x56// -
	//0xaa,0x55// -
	//0xab,0x54// --ON/OFF--
	//0xac,0x53// --アクティブ--
	//0xad,0x52// --ナチュラル--
	//0xae,0x51// --リラックス--
	//0xaf,0x50// スリープタイマー 60分/30分

	//0xb0,0x4f// --明るさ10-- (中略)
	//0xb9,0x46// --明るさ1--
	//0xba,0x45// 明るく
	//0xbb,0x44// 暗く
	//0xbc,0x43// 常夜灯!
	//0xbd,0x42// -
	//0xbe,0x41// OFF!
	//0xbf,0x40// 点灯 常夜灯 OFF
	
	//0x71,// 拡張領域?
		//0x19// 留守番
		//0x22// 残光(ホタルック)
};
```

== 他のフォーマットの対応
Panasonic製の大学の寮のシーリングライトがリモコンに対応しているという話を風の噂で聞きつけた。
調べたところ家製協フォーマットらしい。

#codly(offset:51)
```c
// AEHA Panasonic HK9327K
// https://hello-world.blog.ss-blog.jp/2011-05-07
const uint8_t pana_hk_up[]={0x2c,0x52,0x09,0x2a,0x23};// 明
const uint8_t pana_hk_dn[]={0x2c,0x52,0x09,0x2b,0x22};// 暗
const uint8_t pana_hk_full[]={0x2c,0x52,0x09,0x2c,0x25};// 全灯
const uint8_t pana_hk_on[]={0x2c,0x52,0x09,0x2d,0x24};// 点灯
const uint8_t pana_hk_dim[]={0x2c,0x52,0x09,0x2e,0x27};// 常夜灯
const uint8_t pana_hk_off[]={0x2c,0x52,0x09,0x2f,0x26};// 消灯
```

せっかくなので全てのプロトコルに対応させた。
分周器を調整することでTCA0で使いやすいクロック周波数に都度変更している。

#codly(offset:107)
```c
static void set_38k_wait(t){
	// CLKCTRL CLR_PER=16M/12=1333k Hz
	_PROTECTED_WRITE(CLKCTRL.MCLKCTRLB,CLKCTRL_PDIV_12X_gc|CLKCTRL_PEN_bm);
	// TCA0 IR 1333kHz/35=38.095kHz
	ir_on=12;// CMP 35/3
	TCA0.SINGLE.PER=34;// TOP 35-1
	TCB0.CNT=0;TCB0.CCMP=(8*t+3)/6-1;// TOP round(us2top(t)) (1333333*t+500000)/1000000-1
}
static void set_40k_wait(t){
	// CLKCTRL CLR_PER=16M/16=1000k Hz
	_PROTECTED_WRITE(CLKCTRL.MCLKCTRLB,CLKCTRL_PDIV_16X_gc|CLKCTRL_PEN_bm);
	// TCA0 IR 1000kHz/25=40kHz
	ir_on=8;// CMP 25/3
	TCA0.SINGLE.PER=24;// TOP 25-1
	TCB0.CNT=0;TCB0.CCMP=(2*t+1)/2-1;// TOP round(us2top(t))-1 (1000000*t+500000)/1000000-1
}
static void set_36k_wait(t){
	// CLKCTRL CLR_PER=16M/12=1333k Hz
	_PROTECTED_WRITE(CLKCTRL.MCLKCTRLB,CLKCTRL_PDIV_12X_gc|CLKCTRL_PEN_bm);
	// TCA0 IR 1333kHz/37=36.036kHz
	ir_on=12;// CMP 37/3
	TCA0.SINGLE.PER=36;// TOP 37-1
	TCB0.CNT=0;TCB0.CCMP=(8*t+3)/6-1;// TOP round(us2top(t))-1 (1333333*t+500000)/1000000-1
}
static void set_56k_wait(t){
	// CLKCTRL CLR_PER=16M/48=333k Hz
	_PROTECTED_WRITE(CLKCTRL.MCLKCTRLB,CLKCTRL_PDIV_48X_gc|CLKCTRL_PEN_bm);
	// TCA0 IR 333kHz/6=55.5kHz
	ir_on=2;// CMP 6/3
	TCA0.SINGLE.PER=5;// TOP 6-1
	TCB0.CNT=0;TCB0.CCMP=(2*t+3)/6-1;// TOP round(us2top(t))-1 (333333*t+500000)/1000000-1
}
```

使ってこそいないが、36kHzや56kHzのマイナーな変調にも対応させた。

#codly(offset:148)
```c
static void send_common(const uint8_t ll,const uint8_t *x,const uint8_t l){
	IR_ON;FOR(ll)wait();IR_OFF;FOR(ll/2)wait();
	FOR(l){IR_ON;wait();IR_OFF;wait();if(x[i>>3]>>(i&7)&1)FOR(2)wait();}
	IR_ON;wait();IR_OFF;
}
static void send_nec(const uint8_t *x){set_38k_wait(562);send_common(16,x,32);}
static void send_aeha(const uint8_t *x,const uint8_t l){set_38k_wait(425);send_common(8,x,l);}
static const uint8_t send_sony(
	const uint8_t *x,const uint8_t l
){
	uint8_t t=75-4-l*2;
	set_40k_wait(600);
	IR_ON;FOR(4)wait();IR_OFF;
	FOR(l){wait();IR_ON;wait();if(x[i>>3]>>(i&7)&1){--t;wait();}IR_OFF;}
	return t;
}
```

```c send_xx```で送信できる。

#codly(offset:179)
```c
	while(1){
		sleep();FOR(20)wait();
		const uint8_t x=~VPORTA.IN;
		// ヒューズは書いたか?
		if(x&(1<<6))send_nec(nec_re_cycle);//send_aeha(pana_hk_on,40);
		else if(x&(1<<7))send_nec(nec_re_dim);//send_aeha(pana_hk_dim,40);
		else if(x&(1<<1))send_nec(nec_re_off);//send_aeha(pana_hk_off,40);
		else if(x&(1<<2))send_nec(nec_re_lumi);//send_aeha(pana_hk_off,40);
		// {send_nec(code_g);FOR(150)wait();FOR(4)FORBUF(send_sony(code_e,12))wait();}//send_aeha(code_f,64);
	}
```

実際に寮で動作確認したところ動いた。
嬉しい。

= 結果と今後

記事を書きながら、LED1発ならFETは必要無いのでは、と思い始めたので次はこれも検証したい。

= 余談
今回購入したシーリングライト、赤外線プロトコル以外にももちろん選定理由がある。
幼少期に住んでいた家のリビングのシーリングライトが丸型蛍光灯のもので、この蛍光灯がNECのホタルックであったのだ。
ホタルックは一般的な蛍光灯に加えて蓄光塗料が塗られたもので、消灯後でも暫くの間青緑色の光で足元を照らしてくれるという商品だ。
私はホタルック機能が強く印象に残っていて、シーリングライトを買うときが来たら、ホタルックを買うと端から決めていたのだ。

NECの照明部門は2000年にNECライティング株式会社として分社独立した。
さらに2019年に株式会社ホタルクスが設立され、NECライティング株式会社から全ての事業を継承した。

今日でもホタルックは同社の殆どの家庭用シーリングライトに付属する機能である。
しかし、そこにもはや蓄光塗料は用いられておらず、青緑色のLEDを蓄電素子からの給電で発光させるものに進化していた。
もちろん壁スイッチから電源を切っても機能する。
蓄光塗料の頃はぼんやりと暗くなる挙動だったが、蓄電素子の電圧を監視しているのか、ある程度まで光量が落ちると消灯する。

誰もここ読んでないと思うの。記事の書き出しを書いて満足して水泳欲求に駆られてプールに行った9時間前の自分を張っ倒したい。疲れた。眠い。

単純なシーリングライトとして評価しても、非常に軽量で設置しやすい、リモコンの受信感度も良好、光が良く拡散し天井も明るい、必要十分な機能を揃えていて安価、と、かなり完成度の高いシーリングライトである。

昨今の家電のIoT化の流れにも追従している。
別売りではあるがHotaluX Linkという名称でIoT用のアダプタが販売されている。
面白いのがその取り付け方法で、引掛けシーリング端子に接続するコネクタと交換するだけである。

ホタルクスのシーリングライト、機会があれば是非検討してみてほしい。

= 参考文献
- 赤外線リモコンの通信フォーマット https://elm-chan.org/docs/ir_format.html
- 沿革|会社情報|ホタルクス https://www.hotalux.com/corporate/history.html
