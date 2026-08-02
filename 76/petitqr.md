# JSで画像生成 QRコード編

22 McbeEringi

---

「本日は2024/10/6である。
ネタはまだない。
なにを以て部報を書けばよいか頓と見当がつかぬ。
何でも薄暗いじめじめした所でニャーニャー泣い」

この部法の提出締切日は10/4である。
いいから部報書け。
はい。

## 概要
前々回の部法に於いて、JavaScriptを用いたzip及びpngファイルの生成について執筆した。
今回は、昨今世間にて情報共有や決済の手段としてよく使われるQRコードについて理解を深めるべく、幅広いJS環境に於いて動作するQRコードのエンコーダの実装を1から行う。

### 生成手順
- エンコード対象の文字列郡を用意する
	- `[str,str_]`
- 文字種別を判定して使用するモードを決定する
	- 数字、英数字、8bit、漢字モードがある
- 決定したモードで文字列をエンコードする
	- 同時にヘッダーを付与する
	- ヘッダの一部はバージョンで長さが変動する
	- `[[header,str],[header,str_]]`
- エンコード済みデータの長さからバージョンを決定する
	- ユーザによるエラー訂正レベルの指定も必要である
	- 同時にデータ長が決定する
	- `{ver:N,err_lv:M,data:[[header,str],[header,str]]}`
- 埋め草bit,byteしてバージョンが要求するデータ長に合わせる
	- `{ver:N,ver:N,err_lv:M,data:[[header,str],[header,str],terminator,padding]}`
- バージョンに応じたブロック数に分割してブロック毎にRS符号を付与する
	- `{ver:N,ver:N,err_lv:M,data:[[data,err],[data,err]]}`
- 各ブロックから順番にデータを取り出す
	- 所謂インターリブ配置である
	- `{ver:N,ver:N,err_lv:M,data:interleaved}`
- 機能パターンモジュールを描画する
- 型番情報にBCH符号を付与して描画する
	- バージョン7以上の場合のみである
- インターリブ配置したデータを描画領域右下から順に配置する
- 8通りのマスクから最適なマスクを選択する
- 形式情報にBCH符号を付与して描画する
	- エラー訂正レベルと使用したマスクを含む
- 完成


## day0 2024/1/29
### Reed Solomon 符号
Reed Solomon符号、RS符号とはデータが欠損した場合において、欠損の検出及び元のデータの復号を可能にする追加のデータである。
以下はデータ本体を表現する配列wとRS符号の長さnを取り、RS符号を配列で返す関数rseである。

```js
const
rse=(w,n)=>((
	{exp,log}=[...Array(255)].reduce((a,_,i)=>(a.exp[i]=a.x,a.log[a.x]=i,a.x*=2,(a.x>255)&&(a.x^=0x11d),a),{x:1,exp:[],log:[]}),
	mul=(x,y)=>x&&y&&(x=log[x]+log[y],exp[x]||exp[x-255]),pow=(x,y)=>exp[(log[x]*y)%255],
	g=[...Array(n)].reduce((b,_,k)=>[1,pow(2,k)].reduce((a,y,j)=>(b.forEach((x,i)=>a[i+j]^=mul(x,y)),a),[]),[1]).slice(1)
)=>w.reduce((a,_,i)=>(a[i]&&g.forEach((x,j)=>a[i+j+1]^=mul(x,a[i])),a),w.slice()).slice(-n))();
```
## day1 10/6
文字列をエンコードしたデータを含むブロックを作成する。
```
mode 4bit | length 8~16bit | data Nbit
```
### 符号化
文字種別を判別する。
数字>英数字>漢字>8bitモードの優先順で決定する。
出力は整形のために複数の形式を含むオブジェクトである。
以下は数字モードのマップn、英数モードのマップa、そして漢字モードのマップkを含むmを含むdの宣言及び、文字列wを取りモードに対応する数字を返す関数modeである。
```js
const
d={
	m:{
		enum:['NUM','ALPHANUM','BYTE','KANJI'],
		n:[...Array(10)].reduce((a,_,i)=>(a[i]=i,a),{}),
		a:[...'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:'].reduce((a,x,i)=>(a[x]=i,a),{}),
		k:[...Array(86)].reduce((a,y,_y)=>(y=(_y/2|0)+0x81+0x40*(61<_y),[...Array(_y==85?33:94)].forEach((_,x)=>(x+=_y&1?0x9f:0x40+(62<x),
			a[td_sjis.decode(new Uint8Array([y,x]))]=(y-(0x9f<y?0xc1:0x81))*0xc0+x-0x40
		)),a),{})
	}
},
mode=(w)=>(w=[...w].reduce((a,x)=>(Object.keys(a).forEach(i=>(x in d.m[i])||(a[i]=0)),a),{n:1,a:1,k:1}),w=w.n?0:w.a?1:w.k?3:2,{x:1<<w,l:4,s:w});
```

次に文字種別からモードを決定したらモードに応じた手続きでエンコードする。
あとでbit単位で詰める必要があるのでデータ本体とbit単位のデータ長を持つオブジェクトの配列を返す。
以下は文字列群wを受け取り、対応するqrコードの画素データを返すことを目標に書かれた関数qrの一部である。
ここで、関数qrは文字列の配列wを受け取り、wに、文字列本体w、モードを表すオブジェクトm、そしてエンコード済みのデータdを含むオブジェクトを再代入している。

```js
const
qr=w=>(
	w={
		d:w.map(w=>(
			w={w,m:mode(w)},
			w.d=([
				_=>[...Array(Math.ceil(w.w.length/3))].map((x,i)=>(x=w.w.slice(i*3,++i*3),{x:+x,l:[0,4,7,10][x.length]})),// NUM
				_=>[...Array(Math.ceil(w.w.length/2))].map((x,i)=>(x=w.w.slice(i*2,++i*2),{x:[...x].reduce((a,x)=>a=a*45+d.m.a[x],0),l:[0,6,11][x.length]})),// ALPHANUM
				_=>[...te.encode(w.w)].map(x=>({x,l:8})),// BYTE
				_=>[...w.w].map(x=>({x:d.m.k[x],l:13}))// KANJI
			][w.m.s])(),
```

最後にヘッダーを用意する。
ヘッダーに必要な情報はモードとデータ長とQRコードのバージョン(大きさ)である。
しかしQRコードのバージョンはヘッダーなしでは決定できないので、バージョン番号を引数に取りデータ全体の長さを返す関数で用意する。
再代入されたオブジェクトwに対して、バージョン番号を取りデータ長を表すオブジェクトを返す関数c、そしてバージョン番号を取りヘッダを含むデータ長を返す関数lをメソッドとして宣言した。

```js
			w.c=v=>({x:(w['wd'[w.m.s>>1]].length),l:[[10,12,14],[9,11,13],[8,16,16],[8,10,12]][w.m.s][(9<v)+(26<v)]}),// データ長
			w.l=v=>w.m.l+w.c(v).l+w.d.reduce((a,x)=>a+x.l,0),// ヘッダを含むデータ長
			w
		))
	}
);

```

## day2 10/7
### 表1
表1とはQRコードの仕様書JISX0510 p17に記載されている、バージョン番号と対応するデータ容量についての表である。
表を定数としてそのまま書き写すのは美しくないと考える。
以下はこれをバージョン番号から導出するコード、具体的には
バージョン番号に対して表1に存在するパラメータを含むオブジェクトを返すオブジェクトd.vの宣言である。
```js
d.v=[...Array(40)].reduce((a,x={},i)=>(
	// JISX0510:2018 p17 表1
	x.l=21+i*4,// モジュール数/辺
	x.fpm=(_=>(// 機能パターンモジュール
		_.ap=Math.max(0,_.apps**2-3)*25,// 位置合わせパターンモジュール
		_.tp=(x.l-16-Math.max(0,_.apps-2)*5)*2,// タイミングパターンモジュール
		_.pp+_.ap+_.tp
	))({
		pp:192,// 位置検出及び分離パターンモジュール
		apps:i?((i+1)/7|0)+2:0// 位置合わせパターン/辺
	}),
	x.im=31+(5<i)*18*2,// 形式情報及び型番情報モジュール
	x.dm=x.l**2-x.fpm-x.im,// データモジュール
	x.dw=x.dm>>3,// データ容量
	x.dr=x.dm&7,// 残余ビット

	a[x.ver=i+1]=x,a
),{});
```

## day3 10/8
### 表9で悩む
表9とはQRコードの仕様書JISX0510 p36に記載されている、バージョン番号と対応するブロック数、誤り訂正についての表である。
規則性が殆ど読み取れないので、これを実装するとはつまるところ表を書き写すのみとなるのである。
非常に不本意かつ苦しい行為である。
今日は休むのだ。

## day4 10/9
### 表9の実装
表1の再実装と一緒に実装した。
同時に表E.1も実装した。
表E.1はバージョン番号に対してalignment moduleの座標を定義する表である。
以下はバージョン番号に対して、表1、表9、及び表E.1に存在するパラメータを含むオブジェクトを返すオブジェクトd.vの宣言である。
エラー訂正レベル毎の定義はバージョンに対するオブジェクトの内部にて行われる。

```js
d.v=[// [...ec,...ap] ec[lv=0~3]:[short_data_l,short_blk_n(,long_blk_n)], ap:[6,...ap,l-7]
	[[19,1],[16,1],[13,1],[9,1]],[[34,1],[28,1],[22,1],[16,1]],
	[[55,1],[44,1],[17,2],[13,2]],[[80,1],[32,2],[24,2],[9,4]],
	[[108,1],[43,2],[15,2,2],[11,2,2]],[[68,2],[27,4],[19,4],[15,4]],
	[[78,2],[31,4],[14,2,4],[13,4,1],22],[[97,2],[38,2,2],[18,4,2],[14,4,2],24],
	[[116,2],[36,3,2],[16,4,4],[12,4,4],26],[[68,2,2],[43,4,1],[19,6,2],[15,6,2],28],
	[[81,4],[50,1,4],[22,4,4],[12,3,8],30],[[92,2,2],[36,6,2],[20,4,6],[14,7,4],32],
	[[107,4],[37,8,1],[20,8,4],[11,12,4],34],[[115,3,1],[40,4,5],[16,11,5],[12,11,5],26,46],
	[[87,5,1],[41,5,5],[24,5,7],[12,11,7],26,48],[[98,5,1],[45,7,3],[19,15,2],[15,3,13],26,50],
	[[107,1,5],[46,10,1],[22,1,15],[14,2,17],30,54],[[120,5,1],[43,9,4],[22,17,1],[14,2,19],30,56],
	[[113,3,4],[44,3,11],[21,17,4],[13,9,16],30,58],[[107,3,5],[41,3,13],[24,15,5],[15,15,10],34,62],
	[[116,4,4],[42,17],[22,17,6],[16,19,6],28,50,72],[[111,2,7],[46,17],[24,7,16],[13,34],26,50,74],
	[[121,4,5],[47,4,14],[24,11,14],[15,16,14],30,54,78],[[117,6,4],[45,6,14],[24,11,16],[16,30,2],28,54,80],
	[[106,8,4],[47,8,13],[24,7,22],[15,22,13],32,58,84],[[114,10,2],[46,19,4],[22,28,6],[16,33,4],30,58,86],
	[[122,8,4],[45,22,3],[23,8,26],[15,12,28],34,62,90],[[117,3,10],[45,3,23],[24,4,31],[15,11,31],26,50,74,98],
	[[116,7,7],[45,21,7],[23,1,37],[15,19,26],30,54,78,102],[[115,5,10],[47,19,10],[24,15,25],[15,23,25],26,52,78,104],
	[[115,13,3],[46,2,29],[24,42,1],[15,23,28],30,56,82,108],[[115,17],[46,10,23],[24,10,35],[15,19,35],34,60,86,112],
	[[115,17,1],[46,14,21],[24,29,19],[15,11,46],30,58,86,114],[[115,13,6],[46,14,23],[24,44,7],[16,59,1],34,62,90,118],
	[[121,12,7],[47,12,26],[24,39,14],[15,22,41],30,54,78,102,126],[[121,6,14],[47,6,34],[24,46,10],[15,2,64],24,50,76,102,128],
	[[122,17,4],[46,29,14],[24,49,10],[15,24,46],28,54,80,106,132],[[122,4,18],[46,13,32],[24,48,14],[15,42,32],32,58,84,110,136],
	[[117,20,4],[47,40,7],[24,43,22],[15,10,67],26,54,82,110,138],[[118,19,6],[47,18,31],[24,34,34],[15,20,61],30,58,86,114,142]
].reduce((a,x,i)=>(
	x={_:x},x.l=21+i*4,x.ap=i?[6,...x._.slice(4),x.l-7]:[],// モジュール数/辺 位置合わせパターン座標
	x.de=(x.l**2-(192+Math.max(0,x.ap.length**2-3)*25+(x.l-16-Math.max(0,x.ap.length-2)*5)*2)-(31+(5<i)*36))>>3,// データ容量 (size-(pos+align-timing)-info)/8 cf.p17表1
	x.lv=x._.slice(0,4).map((y,lv)=>(y=y.slice(1).reduce((a,n,i)=>(a.b.push(Array(n).fill(y[0]+i)),a.d+=(y[0]+i)*n,a),{b:[],d:0}),y.b=y.b.flat(),{lv,b:y.b,d:y.d,e:(x.de-y.d)/y.b.length})),// エラー訂正 cf.p36表9
	delete x._,a[x.v=i+1]=x,a
),{});
```
## day5 10/10
### バージョンの自動判定
表9からfindでデータ量が容量以下に収まるバージョンを探索する。
以下は前述にて定義されたd.vを用いて、渡された文字列のエンコード済みデータw.dを格納可能なバージョンw.vを算出し定義するコードである。
```js
w.v=d.v[Object.values(d.v).find(x=>(w.d.reduce((a,y)=>a+y.l(x.v),0)<=x.lv[ecl].d<<3))];
```

### パディング、ブロック分割
エンコード済みデータがバージョンが規定する所定のデータ容量に対して十分な余裕がある場合、末尾に終端パターン`0000`を追加する必要がある。
十分な余裕がない場合は、短縮及び省略が可能である。
バージョンが規定する所定のデータ容量を満たすため、これに対してデータ量が不足する場合は埋め草bit`[0]`及び埋め草byte`[0xec,0x11]`でパディングを行う。
以上の機能を実装した。
以下は前述にて算出されたエンコード済みデータw.dを、一度バイナリを表すStringに分解して、8bit毎に再構成し、終端パターン、埋め草bit,byte、を追加後、w.dを再定義するコードである。
```js
w.d=(b=>[...Array(w.lv.d)].reduce((a,x,i)=>(x=b.slice(i*=8,i+8),a.a.push(x?+('0b'+x.padEnd(8,0)):(a.i^=1)?236:17),a),{a:[],i:0}).a)(
	w.d.flatMap(x=>[x.m,x.c(w.v.v),...x.d].map(({x,l})=>x.toString(2).padStart(l,0))).join('')+'0000'
),
```
### RS符号の生成、インターリーブ
QRコードは一部が欠損している場合に於いて少しでもデコード可能な確率が増すようにRS符号の末尾追加とインターリーブ配置を行う。
以上の機能を実装した。
以下は二次元配列を入力に取り転置と展開を行った結果を一次元配列として返す関数flatTrの定義と、前述したRS符号生成関数rseとflatTrを用いて、w.dに対してその操作を行うコードである。
```js
const
flatTr=w=>w[w.length-1].flatMap((_,i)=>w.reduce((a,x)=>(i in x&&a.push(x[i]),a),[]));
// ...
w.d=(({d,e})=>[d,e].flatMap(flatTr))(w.lv.b.reduce((a,x)=>(a.d.push(x=w.d.slice(a.p,a.p+=x)),a.e.push(rse(x,w.lv.e)),a),{d:[],e:[],p:0})),
```
### 描画系
前々回の部報にて執筆したPNGエンコーダを活用するため、執筆直後にpng.mjsとしてライブラリにまとめた。
今回はこれを活用することで低レイヤなAPIのみを用いてPNGファイルの出力を行った。
以下は、以降画素情報が追加されるオブジェクトw.aからDataURL及びBlobを出力するメソッドを内包するオブジェクトを出力するメソッドw.toPNGの宣言である。
```js
import{png}from{./png.mjs};
w.toPNG=({bg=0xffffffff,fg=0x000000ff,scale:s=4,padding:g=4}={})=>png({data:[...Array(w.v.l+g*2)].flatMap((_,y)=>(y-=g,Array(s).fill([...Array(w.v.l+g*2)].flatMap((_,x)=>(x-=g,
	Array(s).fill(0<=x&&x<w.v.l&&0<=y&&y<w.v.l?w.a[[x,y]].x:0)
))).flat())),width:(w.v.l+g*2)*s,height:(w.v.l+g*2)*s,palette:[bg,fg],alpha:1});

```
### PNGエンコーダの修正
png.mjsでは巨大なデータを扱うことは想定していなかったため、PNGのIDATチャンクの容量が65535Bを超過すると画像が破損する不具合が存在する。
これはdeflate streamのuncompressed blockのデータ長指定が16bitであることに由来するものであり、
uncompressed blockを複数用いることで回避可能である。
この修正を行うことで巨大なデータも正常にPNGとしてエンコードできるよう改良を行った。
String.fromCharCodeの引数の数に制限が存在したため、同様に複数回に処理を分割した。
以下に修正箇所の差分を示す。
```js
...ch([73,68,65,84, 8,29,1, ...((x,l=x.length)=>[l>>>0&255,l>>>8&255,~l>>>0&255,~l>>>8&255,...x,...be4(adler(x))])(
// ...
],{toDataURL(){return'data:image/png;base64,'+btoa(String.fromCharCode(...this));},toBlob(){return new Blob([new Uint8Array(this)],{type:'image/png'})}}))();
```
↓
```js
const
map=(x,f,n=65535)=>[...Array(Math.ceil(x.length/n))].flatMap((_,i,{length:l})=>f(x.slice(n*i,n*i+n),i,l));
// ...
	...ch([73,68,65,84, 8,29, ...(x=>[...map(x,(y,i,a,l=y.length)=>[i==a-1,l>>>0&255,l>>>8&255,~l>>>0&255,~l>>>8&255,...y]),...be4(adler(x))])(
// ...
],{toDataURL(){return'data:image/png;base64,'+btoa(map(this,x=>String.fromCharCode(...x)).join(''));},toBlob(){return new Blob([new Uint8Array(this)],{type:'image/png'})}}))();
```
## day6 10/11

### 機能パターン描画
描画にあたって画像をデータとしてどのように表現するかを考える必要がある。
今回はブラウザのAPIに頼らないことを目標としているのでCanvas APIは使わない。
結果、`w.a[[x座標,y座標].join(',')]={p:[x座標,y座標],x:画素};`とした。
これならObject.assignを用いて複数画素の上書きを容易に行うことができる。

まず、形式情報が格納される場所を予約する。
予約は01以外の値を画素として宣言することで行う。
以下は今回用いるフォーマットを扱いやすくするためのヘルパ関数群の宣言と、w.aを算出し宣言するコードである。
```js
const
oa=Object.assign,
a2px=w=>w.reduce((a,[x,y,f])=>(~f&&(a[[x,y]]={p:[x,y],x:f}),a),{}),// 配列からフォーマット
px=({x,y,f})=>(~f?{[[x,y]]:{p:[x,y],x:f}}:{}),// 画素単体
rect=({x,y=x,w,h=w,f,s=f})=>[...Array(h)].reduce((a,_x,j)=>([...Array(w)].forEach((_y,i,_)=>(_=(!i||i==w-1||!j||j==h-1)?s:f,~_&&(a[[_x=x+i,_y=y+j]]={p:[_x,_y],x:_}))),a),{});// 矩形領域 ストローク機能付き
// ...
w.a=oa(
	a2px([...Array(8)].flatMap((_,i)=>[i+(5<i),w.v.l-1-i].flatMap(x=>[[8,x,2],[x,8,2]]))),//reserve
// ...
```

次に機能パターン、つまりバージョンが確定された時点で描画可能なパターン、具体的には
位置検出パターン(3箇所ある大きな四角)、タイミングパターン(位置検出パターンの内側同士を結ぶ破線)、位置合わせパターン(格子状に配置された小さな四角)を描画する。

```js
// ...
	(({l,ap})=>oa(// functional pattern module
		a2px([...Array(l)].flatMap((x,i)=>(x=(i+1)&1,[[6,i,x],[i,6,x]]))),// time
		oa(...[[0,0,0,0],[l-7,0,-1,0],[0,l-7,0,-1]].map(([x,y,i,j])=>oa(// pos
			rect({x:0+x+i,y:0+y+j,w:8,f:0}),rect({x:0+x,y:0+y,w:7,f:-1,s:1}),rect({x:2+x,y:2+y,w:3,f:1})
		))),
		oa({},...ap.flatMap((y,j)=>ap.map((x,i)=>(i==0&&(j==0||j==ap.length-1)||(i==ap.length-1&&j==0)?{}:oa(// align
			rect({x:x-2,y:y-2,w:5,f:1}),rect({x:x-1,y:y-1,w:3,f:-1,s:0})
		))))),
		px({x:8,y:l-8,f:1})// dark
	))(w.v),
// ...
```

### BCH符号
次に、バージョン7以上の場合に於いて型番情報を算出、描画する。
BCH符号はビット列同士のxorを被除数の桁数回だけ試行することで求めることができる。
以下は桁数を指定可能な被除数及び除数を入力に取りBCH符号を返す関数bchの宣言と、それを用いた型番情報の算出のコードである。
```js
const
bch=({x:x,l:a},{x:y,l:b})=>[...Array(a)].reduce((e,_,i)=>(i++,((e>>(a+b-i))&1)?e^(y<<(a-i)):e),x<<b);

// ...
	// (({v,l})=>6<v?oa(rect({x:l-11,y:0,w:3,h:6,f:2}),rect({x:0,y:l-11,w:6,h:3,f:2})):{})(w.v)// 予約 仮実装
	(({v,l})=>6<v?a2px([...((v<<12)|bch({x:v,l:6},{x:7973,l:12})).toString(2).padStart(18,0)].flatMap((x,i)=>([[...(i=[l-9-i%3,5-(i/3|0)]),+x],[i[1],i[0],+x]]))):{})(w.v)
);

```

### データ描画
QRコードでは、データを右下から幅2マスを保ったまま左方向に蛇腹状に配置する必要がある。
この際、既に描画又は予約済みのマス目を上書きしてはならない。
この実装は些か面倒に思える。
今回は描画済みか否か関係なしに蛇腹状のパターンを生成した後に、描画済みの領域を除去してソートする方針で実装を行った。
以下はデータ配置パターン、w.dmの算出及び宣言と、これを用いてw.aにw.dのデータを配置するコードである。
```js
w.dm=(({l})=>[...Array(l)].flatMap((_,y)=>[...Array(l-1)].flatMap((i,x)=>(
	i=l*2*((l-2-x)>>1)+!(x&1)+((x>>1)&1?l-1-y:y)*2,x+=5<x,
	w.a[[x,y]]?[]:[{p:[x,y],i}]
))).sort(({i:a},{i:b})=>a-b))(w.v);

oa(
	w.a,
	a2px(w.dm.map(({p},i)=>[...p,(w.d[i>>3]>>(7-(i&7)))&1]))
);
```

### マスク
QRコードでは安定した読み取りのために、8種類うち最適なパターンとxorを取ることでデータ中に出現する位置検出パターンに似たパターンを除外している。
最適なパターンは、8種類のマスクで実際にxorを取りパターンを読むことで算出したスコアから決定する。
今となっては一刻も早く完成に漕ぎ着けたい状況なのでマスク0を決め打ちした。
マスク0は`1&~(x+y)`である。
以下はマスク番号を決め打ちし、w.dmを用いてw.aに対してマスクを施すコードである。
```js
w.mask=0;
w.dm.forEach(({p:[j,i]})=>w.a[[j,i]].x^=((i+j)&1)==0);
```

最後にエラー訂正レベルとマスク番号を形式情報として配置する。
型番情報と同じくBCH符号を末尾に追加する。
以下は形式情報をw.aに配置するコードである。
```js
oa(
	w.a,
	(({l},{lv},x=(+'1032'[lv]<<3)|w.mask)=>a2px([...(((x<<10)|bch({x,l:5},{x:1335,l:10}))^21522).toString(2).padStart(15,0)].flatMap((x,i)=>[[i+(5<i)+(6<i&&l-16),8,+x],[8,l-1-(i+(8<i)+(6<i&&l-16)),+x]])))(w.v,w.lv)
),
```

### 完成
「では、己がcp(src)をしようと恨むまいな。己もそうしなければ、饑死をする体なのだ。」
McbeEringiは、すばやく、ソースコード全文をコピペした。
以下がソースコード全文である。
```js
import{png}from'./png.mjs';
/*

thanks to
- [日本産業規格の簡易閲覧 - JISX0510:2018](https://kikakurui.com/x0/X0510-2018-01.html)
- [独極 - 独学QRコード](http://ik1-316-18424.vs.sakura.ne.jp/category/QRCode/index.html)
- [Thonky.com's QR Code Tutorial](https://www.thonky.com/qr-code-tutorial/)
- [Creating a QR Code step by step](https://www.nayuki.io/page/creating-a-qr-code-step-by-step)
- [wikiversity - Reed–Solomon codes for coders](https://en.wikiversity.org/wiki/Reed–Solomon_codes_for_coders)

*/
const
qr=(w,{ecl=0,v=0}={})=>((
	te=new TextEncoder(),td_sjis=new TextDecoder('sjis'),oa=Object.assign,
	d={
		m:{
			enum:['NUM','ALPHANUM','BYTE','KANJI'],
			n:[...Array(10)].reduce((a,_,i)=>(a[i]=i,a),{}),
			a:[...'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:'].reduce((a,x,i)=>(a[x]=i,a),{}),
			k:[...Array(86)].reduce((a,y,_y)=>(y=(_y/2|0)+0x81+0x40*(61<_y),[...Array(_y==85?33:94)].forEach((_,x)=>(x+=_y&1?0x9f:0x40+(62<x),
				a[td_sjis.decode(new Uint8Array([y,x]))]=(y-(0x9f<y?0xc1:0x81))*0xc0+x-0x40
			)),a),{})
		},
		v:[// [...ec,...ap] ec[lv=0~3]:[short_data_l,short_blk_n(,long_blk_n)], ap:[6,...ap,l-7]
			[[19,1],[16,1],[13,1],[9,1]],[[34,1],[28,1],[22,1],[16,1]],
			[[55,1],[44,1],[17,2],[13,2]],[[80,1],[32,2],[24,2],[9,4]],
			[[108,1],[43,2],[15,2,2],[11,2,2]],[[68,2],[27,4],[19,4],[15,4]],
			[[78,2],[31,4],[14,2,4],[13,4,1],22],[[97,2],[38,2,2],[18,4,2],[14,4,2],24],
			[[116,2],[36,3,2],[16,4,4],[12,4,4],26],[[68,2,2],[43,4,1],[19,6,2],[15,6,2],28],
			[[81,4],[50,1,4],[22,4,4],[12,3,8],30],[[92,2,2],[36,6,2],[20,4,6],[14,7,4],32],
			[[107,4],[37,8,1],[20,8,4],[11,12,4],34],[[115,3,1],[40,4,5],[16,11,5],[12,11,5],26,46],
			[[87,5,1],[41,5,5],[24,5,7],[12,11,7],26,48],[[98,5,1],[45,7,3],[19,15,2],[15,3,13],26,50],
			[[107,1,5],[46,10,1],[22,1,15],[14,2,17],30,54],[[120,5,1],[43,9,4],[22,17,1],[14,2,19],30,56],
			[[113,3,4],[44,3,11],[21,17,4],[13,9,16],30,58],[[107,3,5],[41,3,13],[24,15,5],[15,15,10],34,62],
			[[116,4,4],[42,17],[22,17,6],[16,19,6],28,50,72],[[111,2,7],[46,17],[24,7,16],[13,34],26,50,74],
			[[121,4,5],[47,4,14],[24,11,14],[15,16,14],30,54,78],[[117,6,4],[45,6,14],[24,11,16],[16,30,2],28,54,80],
			[[106,8,4],[47,8,13],[24,7,22],[15,22,13],32,58,84],[[114,10,2],[46,19,4],[22,28,6],[16,33,4],30,58,86],
			[[122,8,4],[45,22,3],[23,8,26],[15,12,28],34,62,90],[[117,3,10],[45,3,23],[24,4,31],[15,11,31],26,50,74,98],
			[[116,7,7],[45,21,7],[23,1,37],[15,19,26],30,54,78,102],[[115,5,10],[47,19,10],[24,15,25],[15,23,25],26,52,78,104],
			[[115,13,3],[46,2,29],[24,42,1],[15,23,28],30,56,82,108],[[115,17],[46,10,23],[24,10,35],[15,19,35],34,60,86,112],
			[[115,17,1],[46,14,21],[24,29,19],[15,11,46],30,58,86,114],[[115,13,6],[46,14,23],[24,44,7],[16,59,1],34,62,90,118],
			[[121,12,7],[47,12,26],[24,39,14],[15,22,41],30,54,78,102,126],[[121,6,14],[47,6,34],[24,46,10],[15,2,64],24,50,76,102,128],
			[[122,17,4],[46,29,14],[24,49,10],[15,24,46],28,54,80,106,132],[[122,4,18],[46,13,32],[24,48,14],[15,42,32],32,58,84,110,136],
			[[117,20,4],[47,40,7],[24,43,22],[15,10,67],26,54,82,110,138],[[118,19,6],[47,18,31],[24,34,34],[15,20,61],30,58,86,114,142]
		].reduce((a,x,i)=>(
			x={_:x},x.l=21+i*4,x.ap=i?[6,...x._.slice(4),x.l-7]:[],// モジュール数/辺 位置合わせパターン座標
			x.de=(x.l**2-(192+Math.max(0,x.ap.length**2-3)*25+(x.l-16-Math.max(0,x.ap.length-2)*5)*2)-(31+(5<i)*36))>>3,// データ容量 (size-(pos+align-timing)-info)/8 cf.p17表1
			x.lv=x._.slice(0,4).map((y,lv)=>(y=y.slice(1).reduce((a,n,i)=>(a.b.push(Array(n).fill(y[0]+i)),a.d+=(y[0]+i)*n,a),{b:[],d:0}),y.b=y.b.flat(),{lv,b:y.b,d:y.d,e:(x.de-y.d)/y.b.length})),// エラー訂正 cf.p36表9
			delete x._,a[x.v=i+1]=x,a
		),{})
	},
	mode=(w)=>(w=[...w].reduce((a,x)=>(Object.keys(a).forEach(i=>(x in d.m[i])||(a[i]=0)),a),{n:1,a:1,k:1}),w=w.n?0:w.a?1:w.k?3:2,{x:1<<w,l:4,s:w}),
	rse=(w,n)=>((
		{exp,log}=[...Array(255)].reduce((a,_,i)=>(a.exp[i]=a.x,a.log[a.x]=i,a.x*=2,(a.x>255)&&(a.x^=0x11d),a),{x:1,exp:[],log:[]}),
		mul=(x,y)=>x&&y&&(x=log[x]+log[y],exp[x]||exp[x-255]),pow=(x,y)=>exp[(log[x]*y)%255],
		g=[...Array(n)].reduce((b,_,k)=>[1,pow(2,k)].reduce((a,y,j)=>(b.forEach((x,i)=>a[i+j]^=mul(x,y)),a),[]),[1]).slice(1)
	)=>w.reduce((a,_,i)=>(a[i]&&g.forEach((x,j)=>a[i+j+1]^=mul(x,a[i])),a),w.slice()).slice(-n))(),
	bch=({x:x,l:a},{x:y,l:b})=>[...Array(a)].reduce((e,_,i)=>(i++,((e>>(a+b-i))&1)?e^(y<<(a-i)):e),x<<b),
	// bcha=(a,b)=>[...((a.x<<b.l)|bch(a,b)).toString(2).padStart(a.l+b.l,0)],
	flatTr=w=>w[w.length-1].flatMap((_,i)=>w.reduce((a,x)=>(i in x&&a.push(x[i]),a),[])),
	a2px=w=>w.reduce((a,[x,y,f])=>(~f&&(a[[x,y]]={p:[x,y],x:f}),a),{}),
	px=({x,y,f})=>(~f?{[[x,y]]:{p:[x,y],x:f}}:{}),
	rect=({x,y=x,w,h=w,f,s=f})=>[...Array(h)].reduce((a,_x,j)=>([...Array(w)].forEach((_y,i,_)=>(_=(!i||i==w-1||!j||j==h-1)?s:f,~_&&(a[[_x=x+i,_y=y+j]]={p:[_x,_y],x:_}))),a),{})
)=>(
	w={
		d:w.map(w=>(
			w={w,m:mode(w)},
			w.d=([
				_=>[...Array(Math.ceil(w.w.length/3))].map((x,i)=>(x=w.w.slice(i*3,++i*3),{x:+x,l:[0,4,7,10][x.length]})),// NUM
				_=>[...Array(Math.ceil(w.w.length/2))].map((x,i)=>(x=w.w.slice(i*2,++i*2),{x:[...x].reduce((a,x)=>a=a*45+d.m.a[x],0),l:[0,6,11][x.length]})),// ALPHANUM
				_=>[...te.encode(w.w)].map(x=>({x,l:8})),// BYTE
				_=>[...w.w].map(x=>({x:d.m.k[x],l:13}))// KANJI
			][w.m.s])(),
			w.c=v=>({x:(w['wd'[w.m.s>>1]].length),l:[[10,12,14],[9,11,13],[8,16,16],[8,10,12]][w.m.s][(9<v)+(26<v)]}),
			w.l=v=>w.m.l+w.c(v).l+w.d.reduce((a,x)=>a+x.l,0),
			w
		))
	},
	w.v=d.v[Math.max(v,Object.values(d.v).find(x=>(w.d.reduce((a,y)=>a+y.l(x.v),0)<=x.lv[ecl].d<<3)).v)],
	w.lv=w.v.lv[ecl],
	w.m=w.d.map(x=>d.m.enum[x.m.s]),
	w.d=(b=>[...Array(w.lv.d)].reduce((a,x,i)=>(x=b.slice(i*=8,i+8),a.a.push(x?+('0b'+x.padEnd(8,0)):(a.i^=1)?236:17),a),{a:[],i:0}).a)(
		w.d.flatMap(x=>[x.m,x.c(w.v.v),...x.d].map(({x,l})=>x.toString(2).padStart(l,0))).join('')+'0000'
	),
	w.d=(({d,e})=>[d,e].flatMap(flatTr))(w.lv.b.reduce((a,x)=>(a.d.push(x=w.d.slice(a.p,a.p+=x)),a.e.push(rse(x,w.lv.e)),a),{d:[],e:[],p:0})),
	
	console.log(w.d.map(x=>x.toString(16).padStart(2,0))),

	w.a=oa(
		a2px([...Array(8)].flatMap((_,i)=>[i+(5<i),w.v.l-1-i].flatMap(x=>[[8,x,2],[x,8,2]]))),//reserve
		(({l,ap})=>oa(// functional pattern module
			a2px([...Array(l)].flatMap((x,i)=>(x=(i+1)&1,[[6,i,x],[i,6,x]]))),// time
			oa(...[[0,0,0,0],[l-7,0,-1,0],[0,l-7,0,-1]].map(([x,y,i,j])=>oa(// pos
				rect({x:0+x+i,y:0+y+j,w:8,f:0}),rect({x:0+x,y:0+y,w:7,f:-1,s:1}),rect({x:2+x,y:2+y,w:3,f:1})
			))),
			oa({},...ap.flatMap((y,j)=>ap.map((x,i)=>(i==0&&(j==0||j==ap.length-1)||(i==ap.length-1&&j==0)?{}:oa(// align
				rect({x:x-2,y:y-2,w:5,f:1}),rect({x:x-1,y:y-1,w:3,f:-1,s:0})
			))))),
			px({x:8,y:l-8,f:1})// dark
		))(w.v),
		// (({v,l})=>6<v?oa(rect({x:l-11,y:0,w:3,h:6,f:2}),rect({x:0,y:l-11,w:6,h:3,f:2})):{})(w.v)
		(({v,l})=>6<v?a2px([...((v<<12)|bch({x:v,l:6},{x:7973,l:12})).toString(2).padStart(18,0)].flatMap((x,i)=>([[...(i=[l-9-i%3,5-(i/3|0)]),+x],[i[1],i[0],+x]]))):{})(w.v)
		
	),
	w.dm=(({l})=>[...Array(l)].flatMap((_,y)=>[...Array(l-1)].flatMap((i,x)=>(
		i=l*2*((l-2-x)>>1)+!(x&1)+((x>>1)&1?l-1-y:y)*2,x+=5<x,
		w.a[[x,y]]?[]:[{p:[x,y],i}]
	))).sort(({i:a},{i:b})=>a-b))(w.v),

	oa(
		w.a,
		a2px(w.dm.map(({p},i)=>[...p,(w.d[i>>3]>>(7-(i&7)))&1]))
	),

	w.mask=0,
	w.dm.forEach(({p:[j,i]})=>w.a[[j,i]].x^=((i+j)&1)==0),
	oa(
		w.a,
		(({l},{lv},x=(+'1032'[lv]<<3)|w.mask)=>a2px([...(((x<<10)|bch({x,l:5},{x:1335,l:10}))^21522).toString(2).padStart(15,0)].flatMap((x,i)=>[[i+(5<i)+(6<i&&l-16),8,+x],[8,l-1-(i+(8<i)+(6<i&&l-16)),+x]])))(w.v,w.lv)
	),



	w.toPNG=({bg=0xffffffff,fg=0x000000ff,scale:s=4,padding:g=4}={})=>png({data:[...Array(w.v.l+g*2)].flatMap((_,y)=>(y-=g,Array(s).fill([...Array(w.v.l+g*2)].flatMap((_,x)=>(x-=g,
		Array(s).fill(0<=x&&x<w.v.l&&0<=y&&y<w.v.l?w.a[[x,y]].x:0)
	))).flat())),width:(w.v.l+g*2)*s,height:(w.v.l+g*2)*s,palette:[bg,fg],alpha:1}),

	w
))();

export{qr};
```

依存関係にあるqng.mjsのコード全文は以下の通り。
```js
const// https://qiita.com/McbeEringi/items/9928a9bc05798924e68c
png=({data:d,width:w,height:h,palette:p,alpha:a})=>((
	crc=(t=>(buf,crc=0)=>~buf.reduce((c,x)=>t[(c^x)&0xff]^(c>>>8),~crc))([...Array(256)].map((_,n)=>[...Array(8)].reduce(c=>(c&1)?0xedb88320^(c>>>1):c>>>1,n))),// https://www.rfc-editor.org/rfc/rfc1952
	adler=data=>{let a=1,b=0,len=data.length,tlen,i=0;while(len>0){len-=(tlen=Math.min(1024,len));do{b+=(a+=data[i++]);}while(--tlen);a%=65521;b%=65521;}return(b<<16)|a;},
	be4=x=>[x>>>24&255,x>>>16&255,x>>>8&255,x>>>0&255],ch=x=>[...be4(x.length-4),...x,...be4(crc(x))],bd=[1,2,4,8][p?Math.ceil(Math.log2(Math.ceil(Math.log2(p.length)))):3],bdi=8/bd,
	map=(x,f,n=65535)=>[...Array(Math.ceil(x.length/n))].flatMap((_,i,{length:l})=>f(x.slice(n*i,n*i+n),i,l))
)=>Object.assign([
	137,80,78,71,13,10,26,10,// header
	...ch([73,72,68,82, ...be4(w),...be4(h), bd,p?3:alpha?6:2, 0,0,0]),// IHDR: w h bitDepth colType 0,0,0
	...p?ch([80,76,84,69,...p.flatMap(x=>be4(a?x>>>8:x).slice(1))]):[],// PLTE: ...RGB
	...p&&a?ch([116,82,78,83,...p.map(x=>x&255)]):[],// tRNS: ...alpha
	...ch([73,68,65,84, 8,29, ...(x=>[...map(x,(y,i,a,l=y.length)=>[i==a-1,l>>>0&255,l>>>8&255,~l>>>0&255,~l>>>8&255,...y]),...be4(adler(x))])(
		[...Array(h)].flatMap((_,i)=>(i=d.slice(w*i,w*++i),[0,...p?[...Array(Math.ceil(w/bdi))].map((_,j)=>[...Object.assign(i.slice(bdi*j,bdi*++j),{length:bdi})].reduce((a,x)=>a<<bd|(x&2**bd-1),0)):i]))
	)]),// DATA
	0,0,0,0,73,69,78,68,174,66,96,130// IEND
],{toDataURL(){return'data:image/png;base64,'+btoa(map(this,x=>String.fromCharCode(...x)).join(''));},toBlob(){return new Blob([new Uint8Array(this)],{type:'image/png'})}}))();

export{png};
```

使用例は以下の通り。
```js
import{qr}from'./qr.mjs';
console.log(qr(['こんにちは世界！']).toPNG().toDataURL());
```

ソースコードは以下にて公開している。
なお、このQRコードは今回作成したエンコーダで作成したものである。
![](data:image/png;base64,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)

RS符号の関数を実装して長らく放置していた題目が、こうして日の目を見たことに喜ぶばかりである。
時間に追われて実装したため、合理化できていない箇所が多数見受けられる。
今後数日は各所の修正を行いたい。

### 部報の執筆
時間無さ過ぎてやばいのである。
純アルコール量53.6gの飲酒を行い少々朦朧とした意識でこの記事を執筆していたはずだが、最早酔も冷めてしまいday7、01:52である。
「この記事が部報に掲載されるのか否かすら我々の科学力では分からないのだ。」
皆さんに於いては是非計画的な部法の執筆をされることを期待する。
