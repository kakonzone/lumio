# HTTP stream holdouts

Generated: 2026-06-03T20:02:38Z

Domains below require cleartext in `network_security_config.xml` until migrated.

- `10.0.2.2:8080`
- `103.175.73.12:8080`
- `103.180.212.191:3500`
- `103.182.83.246`
- `115.187.41.216:8080`
- `138.68.138.119:8080`
- `145.239.5.177:80`
- `146.59.253.52:8080`
- `151.80.18.177:86`
- `15.235.185.236`
- `15.235.187.72`
- `158.69.24.53:8080`
- `179.60.224.196:8000`
- `181.118.156.46:8000`
- `181.205.205.173:8888`
- `185.132.134.159:80`
- `185.193.19.32:8082`
- `185.46.48.18:80`
- `185.57.68.33:80`
- `185.57.68.33:8091`
- `198.195.239.50:8095`
- `200.10.30.241:8000`
- `200.115.120.1:8000`
- `202.70.146.135:8000`
- `202.80.222.20`
- `210.4.72.204`
- `212.102.60.80`
- `217.174.225.146`
- `31.148.48.15`
- `41.205.93.154`
- `45.5.119.43:4000`
- `68.183.41.209:8080`
- `82.212.74.98:8000`
- `88.212.15.19`
- `94.136.188.21:8000`
- `99.27.51.147:8080`
- `a-edge.bliscdn.com`
- `alvetv.com`
- `banglajagotv.livebox.co.in:80`
- `bitcdn-kronehit.bitmovin.com`
- `cdn01.palki.tv`
- `cdn.live247stream.com`
- `cdntv.online`
- `epiconvh.akamaized.net`
- `filex.me`
- `hksk.dataplayer.in:8080`
- `iptv.prosto.tv:7000`
- `istream.binarywaves.com:8081`
- `live.dataplayer.in:8080`
- `live-stream.amarbanglatv.in:8080`
- `localhost:8080`
- `stream.pardesitv.online`
- `tv.tuva.ru`
- `unlimited6-cl.dps.live`
- `wo0dyefk.dienalt.org`
- `y3fqd48g.megatv.fun`

## lib/ matches
```
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/api_service.dart:14:    if (envHost.isNotEmpty) return 'http://$envHost:8080';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/api_service.dart:15:    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8080';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/api_service.dart:16:    return 'http://localhost:8080';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/background_service.dart:681:  const fallback = 'http://10.0.2.2:8080'; // Android emulator safe default
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/background_service.dart:709:      return prefs.getString(_baseUrlKey) ?? 'http://10.0.2.2:8080';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/background_service.dart:711:      return 'http://10.0.2.2:8080';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:10:  static const _jioChannelsUrl = 'http://103.180.212.191:3500/channels';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:11:  static const _scanPlaylistUrl = 'http://202.70.146.135:8000/playlist.m3u8';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:12:  static const _jioStreamBase = 'http://103.180.212.191:3500/live/{id}.m3u8';
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:20:http://202.70.146.135:8000/play/a05o/index.m3u8
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:22:http://202.70.146.135:8000/play/a05z/index.m3u8
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:24:http://202.70.146.135:8000/play/a01e/index.m3u8
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:26:http://202.70.146.135:8000/play/a03c/index.m3u8
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:28:http://202.70.146.135:8000/play/a04n/index.m3u8
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:30:http://202.70.146.135:8000/play/a01b/index.m3u8
/home/kakonzone/Downloads/FlutterProject/lumio/lib/services/scanned_iptv_service.dart:32:http://202.70.146.135:8000/play/a04c/index.m3u8
```
