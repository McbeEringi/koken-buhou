#!/bin/env -S typst watch
#import "buhou-tmpl.typ":*
// #show raw.line:it=>{show regex("\S"):it=>sym.zws+it;it}

#show:main.with(
	no:80,
	title:[新しいロゴを描いて Liquid Glass にした],
	author:[22 McbeEringi],
	brief:[
		せっかく新しい工研のロゴを描いたので\
		最近流行りの Liquid Glass を実装して\
		部報の表紙にしてみました
	],
)

= 動機
工研のロゴと言われてあなたはどんな形を想像しますか?
赤い四角が正方形に4つ並んでいるロゴを想像する人が多いと思います。
このロゴにはいくつか問題点がありました。
- ベクターデータが無い
- 実は正方形ではない
- 丸い枠との相性が良くない
- アニメ「けいおん!」のパロディロゴ

もうひ一つ、白地に黒の四角い枠に、繋った工研の文字が斜めに配置されているロゴがありました。
殆どが前述のロゴで置き換えられており、最近はGitHubのOrganizationで見かける程度でした。
こちらもいくつか問題がありました。
- ベクターデータが無い
- 丸い枠との相性が良くない

どちらのロゴも親しまれていましたが、
部のロゴを何かで使うという場面に遭遇する度にイライラしていたので、よいしょで描くことにしました。

= 下書き
一目で工研だとわかるロゴを目標にしました。

工研といえば赤が定着しているので、ベースの色は赤にしました。
ロゴが変わっても雰囲気が似ていれば受け入れられやすいはずです。
元は```text #f00```だったのですが、原色では強すぎるので```text #f12```にしました。

前のロゴの繋がった文字のデザインは個人的にも好きでした。
文字そのものがロゴであればすぐに名前がわかりますから、そのまま採用しました。
しかしそのままでは捻りがありませんから、傾けて勢いをつけてみました。

#figure(
image("./draft.png"),
caption:[最初の下書き]
)


= SVG
ベクターと言えばSVGですよね。
私、個人のもロゴもSVGで描いております。

ということで、いきなり、下書きをSVGに起こしました。

#figure(
image("./logo_stroke.svg"),
caption:[SVG化されたロゴ]
)

#raw(read("./logo_stroke.svg"),lang:"svg",block:true)

非常にシンプルですね、読めばわかる程度かと思うので説明は割愛します。
これをuseとviewタグで色違いも含めたファイルにしました。

#figure(
image("./logo.svg"),
caption:[SVG化されたロゴ]
)

```svg
<a href=""   transform="translate( 0, 0)"><use href="#bg" fill="#fff"/><use href="#main" stroke="#f12"/></a>
<view id="!" viewBox="38 6 20 20"/>
<a href="#!" transform="translate(32, 0)"><use href="#bg" fill="#222"/><use href="#main" stroke="#f12"/></a>
<view id="_" viewBox="70 6 20 20"/>
<a href="#_" transform="translate(64, 0)"><use href="#main" stroke="#f12"/></a>

<view id="-"  viewBox="6 38 20 20"/>
<a href="#-"  transform="translate( 0,32)"><use href="#bg" fill="#fff"/><use href="#main" stroke="#222"/></a>
<view id="-!" viewBox="38 38 20 20"/>
<a href="#-!" transform="translate(32,32)"><use href="#bg" fill="#222"/><use href="#main" stroke="#fff"/></a>
<view id="-_" viewBox="6 70 20 20"/>
<a href="#-_" transform="translate(0,64)"><use href="#main" stroke="#222"/></a>
<view id="-!_" viewBox="38 70 20 20"/>
<a href="#-!_" transform="translate(32,64)"><use href="#main" stroke="#fff"/></a>

<view id="$" viewBox="0 0 96 96"/>
<view id="d" viewBox="64 64 32 32"/>
```
気になることがあれば全て公開していますから、こちらを参照してください。

#qr("https://github.com/ueckoken/logo")

これ以降の実装も全てここにあります。

= OpenSCAD

3Dプリンタで印刷したいのでOpenSCADで使えるようにしました。
といっても、OpenSCADにはSVGを2D図形としてインポートする機能があので、これを押し出すだけです。

```openscad
linear_extrude(1)offset(2)import("logo_scad.svg");
```

交点が抜けるのを防ぐため、あらかじめ線幅を細くしたロゴをoffsetで太らせています。
#figure(
image("./scad.png"),
caption:[OpenSCADにimport]
)
#figure(
image("./spray.jpg"),
caption:[23 kat0hによる塗装]
)
#figure(
image("./3dp.jpg"),
caption:[印刷されるロゴ]
)

= GLSL (SDF)
CGといえばシェーダー、シェーダーと言えばGLSLだと思います。
GLSLはOpenGLで使われるシェーダー言語で、GPUで実行されるプログラムを記述することができます。
GLSLで図形を定義する場合、Signed Distance Field (SDF)と呼ばれる手法が良く使われます。
これは図形の境界面を0とし、そこからの距離を返す関数です。
図形の内側は負の数になります。
SDFは、複数の図形をmin関数で結合できます。

ここまで来れば、SVGでpathを使って定義された図形が、SDFに容易に移植可能であることが想像できるはずです。

SDFの基本図形については、こちらを参照してください。
#qr("https://iquilezles.org/articles/distfunctions/")


絶対座標に直されたpathコマンド郡をそのままGLSLにしました。

```glsl
float logo(vec3 _p,float x){
	vec3 p=(mat4(
		1, 0,0,0,
		0,-1,0,0,
		0, 0,1,0,
		0, 1,0,0
	)*vec4(_p,1)).xyz*20.;
	
	return
	U(
		U(
			U(
				U(
					L(-2,7,9,4.25),
					L(6,5,6,10)
				),U(
					L(2,11,13,8.25),L(14,8,18,7)
				)
			),
			U(
				U(
					L(14,11,22,9),
					U(U(
						L(11,14.75,13,14.25),
						L(13,14.25,13,11.25)
					),U(
						L(13,11.25,11,11.75),
						L(11,11.75,11,16)
					))
				),
				L(17,7.25,17,22)
			)
		),
		U(
			A(5,10,6,-acos(cl(6.)/6.),acos(4./6.)),
			A(5,10,10,-acos(cl(10.)/10.),asin(5./10.))
		)
	);
}
```

defineで距離関数に落してあります。
```glsl
#define U(A,B) smin(A,B,x)
#define L(AX,AY,BX,BY) line(p,vec3(AX,AY,0),vec3(BX,BY,0),.5)
#define A(OX,OY,R,A0,A1) _A(p,vec2(OX,OY),float(R),vec2(A0,A1),.5)

// https://iquilezles.org/articles/distfunctions/
float arc(vec3 p,vec2 sc,float ra,float rb){
	p.x=abs(p.x);
	float k=(sc.y*p.x>sc.x*p.y)?dot(p.xy,sc):length(p.xy);
	return sqrt(dot(p,p)+ra*ra-2.*ra*k)-rb;
}
float line(vec3 p,vec3 a,vec3 b,float r){
	vec3 pa=p-a,ba=b-a;
	float h=clamp(dot(pa,ba)/dot(ba,ba),0.,1.);
	return length(pa-ba*h)-r;
}
float _A(vec3 _p,vec2 o,float ra,vec2 a,float rb){
	float amean=dot(a,vec2(.5))-PI*.5;
	float adiff=min(abs(dot(a,vec2(-1,1)))*.5,2.*PI);
	vec4 p=mat4(
			cos(amean),-sin(amean),0,0,
			sin(amean),cos(amean),0,0,
			0,0,1,0,
			0,0,0,1
		)*mat4(
			1,0,0,0,
			0,1,0,0,
			0,0,1,0,
			-o.x,-o.y,0,1
		)*vec4(_p,1);
	return arc(p.xyz,vec2(sin(adiff),cos(adiff)),ra,rb);
}
```

= Liquid Glass

Liquid Glassはここ最近になってAppleが使いはじめたデザインセットです。
大きめに取られた角丸と、縁で屈折した透明な背景が特徴です。

== 法線

屈折の表現が必要ということは、屈折する面の法線ベクトルが必要ということです。
SDFは距離のみを返すため、そのままでは法線ベクトルを取ることはできません。
近傍の値との差を取ることで法線を得ることができます。

```glsl
vec2 n=normalize(vec2(
	logo(p,t)-logo(p+vec3(.01,0,0),t),
	logo(p,t)-logo(p+vec3(0,.01,0),t)
));
```

== ノイズ
すりガラス風の効果を乗せるためにノイズを使います。
滑らかなノイズとしてパーリンノイズやシンプレックスノイズがありますが、今回はただのノイズを使います。

#qr("https://www.shadertoy.com/view/4djSRW")
```glsl
vec2 hash22(vec2 p){
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx+33.33);
	return fract((p3.xx+p3.yz)*p3.zy);
}
```

```glsl
vec2 noise=(hash22(texp*1024.)-.5)*bg_noise_intensity;
```


== 色収差

ひどいレンズで撮った写真の縁が虹みたいになって、ぼやけることがありますね。
あれが色収差です。
屈折を賑やかにしたいときの表現として優秀です。

今回は同じテクスチャを3回ずらして読む実装にしました。

```glsl
vec3(
	texture2D(tex0,texp+noise*bi+(n*cdb)*(reflact_intensity-chroma_abr_intensity)).r,
	texture2D(tex0,texp+noise*bi+(n*cdb)*(reflact_intensity)).g,
	texture2D(tex0,texp+noise*bi+(n*cdb)*(reflact_intensity+chroma_abr_intensity)).b
)
```

== 結果

#figure(
image("./rendered.png"),
caption:[表紙横バージョン]
)
#figure(
image("./zoom.png"),
caption:[拡大]
)

本家 Liquid Glass で見られる縁付近で内側と同じ場所が歪んで見える現象もしっかり再現できています。

= 感想
本当は部報の文字もデザインしたかったのですが、雰囲気を揃えようとすると上手くグリッドに乗ってくれなくて断念しました。
様々な形式、特に3Dプリント可能な形式のロゴを皆さん使ってくれた嬉しい限りです。
SVGをSDFに落としこむ試みは今回が始めてだったのですが、なかなか上手く行って満足です。

GitHubのロゴアセット郡は以下のサブドメインで公開されています。
是非参考にしてみてください。

#qr("https://logo.ueckoken.club/")
