#import "@preview/codly:1.3.0":*
#import "@preview/codly-languages:0.1.10":*
#import "@preview/zebra:0.1.0":qrcode

#let main(
  no:"XX",
  title:"部報サンプル",author:"XX 工研太郎",brief:"Hello from typst!",
  serif:"Noto Serif CJK JP",
  sansserif:"Noto Sans CJK JP",
  monospace:("Monaspace Argon","Noto Sans CJK JP"),
  cfg:(
    hr:0.2mm,
  ),
  margin:(top:3cm,x:2cm,bottom:3cm),
  body
)={
  show:codly-init.with()
  codly(languages:codly-languages)

  set page(
    paper:"a4",margin:margin,
    header:grid(columns:(auto,1fr,auto),stroke:(bottom:cfg.hr),inset:(bottom:.5em))[][][工学研究部 部報 #no 号],
    footer:grid(columns:(auto,1fr,auto),stroke:(top:cfg.hr),inset:(top:.5em))[電気通信大学 工学研究部][][
      #align(right)[
        #link("https://ueckoken.club/")\
        #link("ueckoken@gmail.com")
      ]
    ]
  )
  set line(length:50%,stroke:(thickness:cfg.hr,paint:gray))
  set par(first-line-indent:(amount:1em,all:true))
  set text(
    lang:"ja",region:"jp",
    font:serif,weight:"regular",size:12pt
  )
  set heading(numbering:"1.1  ")
  show heading:set text(font:sansserif,weight:"medium")
  // show heading.where(level:1):x=>text(size:13pt,x)
  // show heading.where(level:2):x=>text(size:12pt,x)
  show link:set text(font:monospace,size:9pt)
  show raw:set text(font:monospace)

  v(2em)
  align(center)[
    #text(size:20pt,font:sansserif,title)#v(1em)
    #text(size:14pt,font:sansserif,author)#v(1em)
    #box(inset:(x:2em),text(size:10pt,brief))#v(1em)
    #line()
  ]
  // show:columns.with(2)
  body
}

#let url(
  url
)={
  figure(qrcode(url),caption:[#link(url)])
}
