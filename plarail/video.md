# ESPから映像を転送

22 McbeEringi

---

2023年度の調布祭のプラレール企画で前面展望を

ブラウザとESP32でデータを送受信する場合、WebSocketを用いることが多い。
有志によるライブラリが整備されており容易に開発可能である。
しかし映像の転送ではWebSocketでは少々不便である。
WebSocketはTCP上に構築された通信であり、例えばパケ詰まりで映像が止まってしまう、映像のフレーム数が思うように増やせない等が問題になる。

映像に於いては転送順の保証やパケットロスがないことよりリアルタイム性が重要であり、TCPよりUDPが適している。
これにより上記の問題を解決することが可能だが、ブラウザの標準APIにUDPを扱えるものが存在しないためnodejs等でデータを仲介してやる必要がある。


今回は
ESPからPCのnodejsをUDP、nodejsとブラウザの間をWebSocketで接続した。


まずはカメラモジュールの機能で画像をJPEGとして取得する。
UDPには1パケットに送信できるデータ量の上限が存在するのでこれを複数のパケットに分割して送信。
フレーム番号、フレームの分割数、現在のパケット番号をそれぞれ1byteで表現、その後にデータ本体を乗せる。

```cpp
#include <Arduino.h>
#include <WiFi.h>
#include <WiFiUDP.h>
#include <ESPmDNS.h>
#include <esp_camera.h>

#define HOST "toko-minibookx"
#define PORT 3333
#define SIZE 1024

WiFiUDP udp;
IPAddress host;
uint8_t t=0;

static camera_config_t cam_cfg={// https://github.com/espressif/esp-who/blob/master/docs/en/Camera_connections.md
	.pin_pwdn=-1,.pin_reset=-1,

	#ifdef ARDUINO_XIAO_ESP32S3
	.pin_xclk=10,.pin_sccb_sda=40,.pin_sccb_scl=39,

	.pin_d7=48,.pin_d6=11,.pin_d5=12,.pin_d4=14,.pin_d3=16,.pin_d2=18,.pin_d1=17,.pin_d0=15,
	.pin_vsync=38,.pin_href=47,.pin_pclk=13,
	#else
	.pin_xclk=4,.pin_sccb_sda=18,.pin_sccb_scl=23,

	.pin_d7=36,.pin_d6=37,.pin_d5=38,.pin_d4=39,.pin_d3=35,.pin_d2=14,.pin_d1=13,.pin_d0=34,
	.pin_vsync=5,.pin_href=27,.pin_pclk=25,
	#endif

	.xclk_freq_hz=20000000,//EXPERIMENTAL: Set to 16MHz on ESP32-S2 or ESP32-S3 to enable EDMA mode
	.ledc_timer=LEDC_TIMER_0,.ledc_channel=LEDC_CHANNEL_0,

	.pixel_format=PIXFORMAT_JPEG,//YUV422,GRAYSCALE,RGB565,JPEG
	.frame_size=FRAMESIZE_SVGA,//QQVGA-UXGA, For ESP32, do not use sizes above QVGA when not JPEG. The performance of the ESP32-S series has improved a lot, but JPEG mode always gives better frame rates.

	.jpeg_quality=12, //0-63, for OV series camera sensors, lower number means higher quality
	.fb_count=2, //When jpeg mode is used, if fb_count more than one, the driver will work in continuous mode.
	.grab_mode=CAMERA_GRAB_WHEN_EMPTY//CAMERA_GRAB_LATEST. Sets when buffers should be filled
};

void setup(){
	psramInit();pinMode(21,OUTPUT);digitalWrite(21,HIGH);delay(200);digitalWrite(21,LOW);

	WiFi.begin();
	for(uint8_t i=0;WiFi.status()!=WL_CONNECTED;i++){
		if(i>20){
			
			WiFi.beginSmartConfig();while(!WiFi.smartConfigDone()){delay(200);digitalWrite(21,HIGH);delay(200);digitalWrite(21,LOW);};
		}
		delay(500);
	}
	MDNS.begin("udp-cam");
	host=MDNS.queryHost(HOST);
	esp_camera_init(&cam_cfg);
	digitalWrite(21,HIGH);
}

void loop(){
	camera_fb_t *fb=esp_camera_fb_get();
	for(uint8_t n=(fb->len+SIZE-1)/SIZE,i=0;i<n;i++){
		udp.beginPacket(host,PORT);udp.write(t);udp.write(n);udp.write(i);udp.write(fb->buf+SIZE*i,i+1==n?fb->len-SIZE*i:SIZE);udp.endPacket();
	}
	t++;
	esp_camera_fb_return(fb);
}
```

nodejsでは各フレームについてすべてのパケットを受信した場合に画像データを再構築し、すべてのWebSocketクライアントに送信する。
これにより画像の乱れを防ぐことができる。


```js
import * as DGRAM from 'node:dgram';
import * as HTTP from 'node:http';
import * as WS from 'ws';

const
fb={},
udp=DGRAM.createSocket('udp4'),
svr=HTTP.createServer((req,res)=>(
	res.writeHead(200,{'Content-Type':'text/html'}),
	res.end(`
	<!DOCTYPE html>
	<html lang="en" dir="ltr">
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width,initial-scale=1">
		<title>video</title>
	</head>
	<body>
		<style>:root,body,#img{width:100%;height:100%;margin:0;background-color:#00f;object-fit:contain;vertical-align:top;}</style>
		<img id="img">
		<script>
			'use strict';
			let ws={},t;
			const
				main=_=>(
					ws=Object.assign(new WebSocket(\`ws://\${location.hostname}/ws\`),{
						binaryType:'arraybuffer',
						onopen:_=>console.log('Opened'),
						onclose:_=>console.log('Closed',main()),
						onmessage:e=>img.src='data:image/jpeg;base64,'+btoa(String.fromCharCode(...new Uint8Array(e.data)))
					})
				);
			img.onload=_=>console.log(Math.round(1000/(-t+(t=performance.now()))));
			document.onvisibilitychange=_=>ws.send('');
			onload=main;
		</script>
	</body>
	</html>
	`)
)),
ws=new Set(),
wss=new WS.WebSocketServer({server:svr,path:'/ws'});

wss.on('connection',_=>ws.add(_));
wss.on('close',_=>ws.delete(_));
udp.on('message',(x,i)=>(
	x={
		t:x[0],
		n:x[1],
		i:x[2],
		x:x.subarray(3)
	},
	fb[x.t]||(fb[x.t]=[...Array(x.n)],setTimeout(_=>delete fb[x.t],500)),
	fb[x.t][x.i]=x.x,
	fb[x.t].every(_=>_)&&((_=Buffer.concat(fb[x.t]))=>(
		ws.forEach(x=>x.send(_)),
		console.log({size:_.length,t:x.t,packets:fb[x.t].length}),
		delete fb[x.t]
	))()
	// console.log(x+'',i.address,i.port)
));
udp.on('listening',_=>console.log(`port ${udp.address().port} ...`));
udp.bind(3333);
svr.listen(80);
```


展望

WebRTC及びそのDataChannelを用いる