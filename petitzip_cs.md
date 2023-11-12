# JSで ファイル生成 ZIP番外編 ~ 『圧縮』した~

22 McbeEringi

「JSで ファイル生成 ZIP編」の続きです。思わぬ進捗が生まれたので。

---

## 便利なAPIの登場

ZIP編で非圧縮のZIPファイルを生成した。
ところで最近のブラウザにはこんなAPIがある。
以下MDNからの引用である。

> ## Compression Streams API
>
>Compression Streams API は、gzip 形式や deflate 形式によるデータのストリームの圧縮や展開を行う JavaScript の API を提供します。
>
>ビルトインの圧縮機能を使うことで、JavaScript のアプリケーションに圧縮ライブラリーを含める必要がなくなり、アプリケーションのダウンロードサイズをより小さくできます。
>
> ### インターフェイス
>
> `CompressionStream` データのストリームを圧縮します。
> `DecompressionStream` データのストリームを展開します。
>
> ### 例
>
> この例では、ストリームを gzip 圧縮により圧縮します。
>
> ``` js
> const compressedReadableStream = inputReadableStream.pipeThrough(
>   new CompressionStream("gzip"),
> );
> ```
>
> この例は、blob を gzip により展開する関数です。
>
> ```js
> async function DecompressBlob(blob) {
>   const ds = new DecompressionStream("gzip");
>   const decompressedStream = blob.stream().pipeThrough(ds);
>   return await new Response(decompressedStream).blob();
> }
> ```

deflateの自前実装を考えていたが、便利なAPIを見つけてしまったのでこれを用いてZIP圧縮を行う。

## 変更箇所

非圧縮と圧縮で変更の必要のある項目が存在する

|項目|変更前|変更後|
|-|-|-|
|作成されたバージョン|v1.0 = 0d10|v2.0 = 0d20|
|展開に必要なバージョン|v1.0 = 0d10|v2.0 = 0d20|
|圧縮メソッド|0|8|
|圧縮サイズ|= 非圧縮サイズ|圧縮サイズ|

deflateは圧縮モード8である。
deflateの使用にはv2.0が必要である。

## 実装

Compression Streams APIのコンストラクタがとる引数は3種類ある。

- 'deflate'
- 'deflate-raw'
- 'gzip'

注意すべき点が'deflate'はzlibのことでありdeflateは'deflate-raw'である点である。
ZIPのdeflateはzlibではないので'deflate-raw'を使うことになる。

以下実装である。
引数csの真偽とCompressionStreamの有無を判定してどちらかが偽であれば非圧縮での動作となる。

```js
const
zip=(w=[],f=_=>_,cs)=>((
  u=x=>new Uint8Array(x),
  zz=u([0,0],cs=cs&&self.CompressionStream),
  vz=u([cs?20:10,0]),pk=u([80,75]),_12=u([1,2]),_34=u([3,4]),gf=u([8,0]),
  cm=cs?gf:zz,te=new TextEncoder(),i=0,
  le2=x=>u([x,x>>>8]),le4=x=>u([x,x>>>8,x>>>16,x>>>24]),
  l=x=>x.byteLength||x.size||0,cnt=x=>le4(x.reduce((a,y)=>a+l(y),0)),
  iab=x=>x instanceof ArrayBuffer,
  dfl=b=>cs?new Response((iab(b)?new Blob([b]):b).stream().pipeThrough(new cs('deflate-raw'))).blob():b,
  ddt=x=>((x.getFullYear()-1980)<<25)|((x.getMonth()+1)<<21)|(x.getDate()<<16)|(x.getHours()<<11)|(x.getMinutes()<<5)|(x.getSeconds()>>1),// mmmsssss hhhhhmmm MMMDDDDD YYYYYYYM // Y-=1980;s/=2;
  crc=(t=>(buf,crc=0)=>~buf.reduce((c,x)=>t[(c^x)&0xff]^(c>>>8),~crc))([...Array(256)].map((_,n)=>[...Array(8)].reduce(c=>(c&1)?0xedb88320^(c>>>1):c>>>1,n)))// https://www.rfc-editor.org/rfc/rfc1952
)=>w.reduce(async(a,x,b,cb,n)=>(
  cb=await dfl(b=x.buffer||x),
  f(++i/w.length/3),
  n=te.encode(x.name),
  x=[// vReq flag cpsType date CRC32 cpsSize rawSize nameLength extLength
    vz,gf,cm,le4(ddt(new Date(x.lastModified))),
    le4(crc(u(iab(b)?b:await new Response(b).arrayBuffer()))),
    le4(l(cb)),le4(l(b)),le2(l(n)),zz
  ],
  f(++i/w.length/3),
  a=await a,
  f(++i/w.length/3),
  a.cd.push(pk,_12,vz,...x,zz,zz,zz,zz,zz,cnt(a.lf),n),// PK0102 vMade x cmtLength 0304disk intAttr extAttrLSB extAttrMSB 0304pos name
  a.lf.push(pk,_34,...x,n,cb),// PK0304 x name content
  a
),{lf:[],cd:[]}).then((x,_=le2(w.length))=>new Blob([
  ...x.lf,...x.cd,pk,u([5,6]),zz,zz,_,_,cnt(x.cd),cnt(x.lf),zz// PK0506 disk 0304startDisk cnt0102disk cnt0102all 0102size 0102pos cmtLength
],{type:'application/zip'})))();
```

## 結果

テキストファイルのみのフォルダにおいては非圧縮と圧縮で約3.5倍の差が確認できた。
一方mp3のみのフォルダにおいてはほとんど差は見受けられなかった。
どちらも7-Zipを用いて正常に解凍できた。

## 参考文献

<https://developer.mozilla.org/ja/docs/Web/API/Compression_Streams_API>
