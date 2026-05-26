import '../models/model.dart';
import 'extra_channels.dart';

/// User-pasted m3u8 list — merged once; appears in Categories, Live nav & Sports.
class UserPasteChannels {
  UserPasteChannels._();

  static const _ip = 'http://198.195.239.50:8095';

  static List<ChannelModel> get all => [
        ExtraChannels.fromMultiLinkPaste(
          'T Sports',
          'Sports',
          '''
$_ip/Tsports/index.m3u8
$_ip/Tsports/tracks-v1a1/mono.m3u8
''',
          id: 'paste_tsports',
          country: 'Bangladesh',
          viewers: 20000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Star Sports 2',
          'Sports',
          '''
$_ip/StarSports2/index.m3u8
''',
          id: 'paste_ss2',
          country: 'India',
          viewers: 15000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Star Sports Select 1',
          'Sports',
          '''
$_ip/StarSportsSelect1/index.m3u8
''',
          id: 'paste_sss1',
          country: 'India',
          viewers: 12000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Star Sports Select 2',
          'Sports',
          '''
$_ip/StarSportsSelect2/index.m3u8
''',
          id: 'paste_sss2',
          country: 'India',
          viewers: 12000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Sony Ten Sports 2',
          'Sports',
          '''
$_ip/SonyTenSports2/index.m3u8
''',
          id: 'paste_st2',
          country: 'India',
          viewers: 11000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Sony Ten Sports 5',
          'Sports',
          '''
$_ip/SonyTenSports5/index.m3u8
$_ip/SonyTenSports5/tracks-v1a1/mono.m3u8
''',
          id: 'paste_st5',
          country: 'India',
          viewers: 11000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Eurosport',
          'Sports',
          '''
$_ip/Eurosport/index.m3u8
http://151.80.18.177:86/Eurosport_HD/index.m3u8
http://103.159.180.34:5001/live/875.m3u8
''',
          id: 'paste_eurosport',
          country: 'UK',
          viewers: 9000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Nagorik TV',
          'Sports',
          '''
$_ip/nagorik/index.m3u8
$_ip/nagorik/tracks-v1a1/mono.m3u8
https://owrcovcrpy.gpcdn.net/bpk-tv/1718/output/index.m3u8
''',
          id: 'paste_nagorik_sport',
          country: 'Bangladesh',
          viewers: 9000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'News24 BD',
          'Bangladesh',
          '''
$_ip/News24/index.m3u8
$_ip/News24/tracks-v1a1/mono.m3u8
https://owrcovcrpy.gpcdn.net/bpk-tv/1708/output/index.m3u8
''',
          id: 'paste_news24',
          country: 'Bangladesh',
          viewers: 8000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Jalsha Movies',
          'Movies',
          '''
$_ip/JalshaMovies/index.m3u8
$_ip/JalshaMovies/tracks-v1a1/mono.m3u8
''',
          id: 'paste_jalsha',
          country: 'India',
          viewers: 7000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Zee Bangla Cinema',
          'Movies',
          '''
$_ip/ZeeBanglaCinema/index.m3u8
$_ip/ZeeBanglaCinema/tracks-v1a1/mono.m3u8
''',
          id: 'paste_zbc',
          country: 'India',
          viewers: 7000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Colors Bangla Cinema',
          'Movies',
          '''
$_ip/ColorsBanglaChinema/index.m3u8
$_ip/ColorsBanglaChinema/tracks-v1a1/mono.m3u8
''',
          id: 'paste_cbc',
          country: 'Bangladesh',
          viewers: 6500,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Sony Aath',
          'Entertainment',
          '''
$_ip/SonyAath/index.m3u8
$_ip/SonyAath/tracks-v1a1/mono.m3u8
''',
          id: 'paste_sonyaath',
          country: 'India',
          viewers: 6000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Sony MAX',
          'Movies',
          '''
$_ip/SonyMAX/index.m3u8
$_ip/SonyMAX/tracks-v1a1/mono.m3u8
''',
          id: 'paste_sonymax',
          country: 'India',
          viewers: 8000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Sony TV',
          'Entertainment',
          '''
$_ip/SonyTv/index.m3u8
$_ip/SonyTv/tracks-v1a1/mono.m3u8
''',
          id: 'paste_sonytv',
          country: 'India',
          viewers: 6000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Star Plus',
          'Hindi',
          '''
$_ip/StarPlus/index.m3u8
''',
          id: 'paste_starplus',
          country: 'India',
          viewers: 7000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Star Gold',
          'Movies',
          '''
$_ip/StarGold/index.m3u8
''',
          id: 'paste_stargold',
          country: 'India',
          viewers: 7000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Star Movies',
          'Movies',
          '''
$_ip/StarMovies/index.m3u8
''',
          id: 'paste_starmovies',
          country: 'India',
          viewers: 7000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Zee TV',
          'Hindi',
          '''
$_ip/ZeeTV/index.m3u8
''',
          id: 'paste_zeetv',
          country: 'India',
          viewers: 7000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Discovery',
          'English',
          '''
$_ip/Discovery/index.m3u8
''',
          id: 'paste_discovery',
          country: 'UK',
          viewers: 5000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'National Geographic',
          'English',
          '''
$_ip/NationalGeographic/index.m3u8
http://151.80.18.177:86/National_Geo_HD/index.m3u8
''',
          id: 'paste_natgeo',
          country: 'UK',
          viewers: 5000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Cartoon Network',
          'Kids',
          '''
$_ip/CartoonNetwork/index.m3u8
https://s3.ideationtec.live/Cartoon_Network/Cartoon_Network.m3u8
''',
          id: 'paste_cn',
          country: 'India',
          viewers: 5000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Discovery Kids',
          'Kids',
          '''
$_ip/DiscoveryKids/index.m3u8
$_ip/DiscoveryKids/tracks-v1a1/mono.m3u8
https://vodzong.mjunoon.tv:8087/streamtest/disckids-157-1/playlist.m3u8
''',
          id: 'paste_disckids',
          country: 'India',
          viewers: 4500,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'beIN Sports',
          'Sports',
          '''
http://99.27.51.147:8080/BeinSport/index.m3u8
http://99.27.51.147:8080/BeinSport3/index.m3u8
https://bein-esp-xumo.amagi.tv/playlistR1080p.m3u8
''',
          id: 'paste_bein',
          country: 'Qatar',
          viewers: 12000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Star Sports 1',
          'Sports',
          '''
http://41.205.93.154/STARSPORTS1/index.m3u8
http://149.71.34.166:8000/play/a01k/index.m3u8
''',
          id: 'paste_ss1',
          country: 'India',
          viewers: 18000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Trace Sport',
          'Sports',
          '''
https://lightning-tracesport-samsungau.amagi.tv/playlist.m3u8
https://cdn-uw2-prod.tsv2.amagi.tv/linear/amg02873-kravemedia-mtrspt1-distrotv/playlist.m3u8
''',
          id: 'paste_trace',
          country: 'International',
          viewers: 4000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Arena Sport',
          'Sports',
          '''
http://88.212.15.19/live/test_arenasport/playlist.m3u8
http://88.212.15.19/live/test_arenasport_dva/playlist.m3u8
http://88.212.15.19/live/test_sport1_25p/playlist.m3u8
http://88.212.15.19/live/test_sport_2/playlist.m3u8
http://88.212.15.19/live/test_ctsport_25p/playlist.m3u8
''',
          id: 'paste_arena',
          country: 'Europe',
          viewers: 5000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Sport IPTV Pack',
          'Sports',
          '''
http://185.132.134.159:80/sport1/index.m3u8
http://185.132.134.159:80/sport2/index.m3u8
http://185.132.134.159:80/sport3/index.m3u8
http://185.132.134.159:80/sport4/index.m3u8
http://185.132.134.159:80/sport5/index.m3u8
http://185.132.134.159:80/sport6/index.m3u8
http://185.46.48.18:80/match/tracks-v1a1/mono.m3u8
http://212.102.60.80/Infosport/index.m3u8
http://151.80.18.177:86/Canal+_sport_HD/index.m3u8
http://tv.tuva.ru/machtv/index.m3u8
https://tva.in.ua/live/susp-sport.m3u8
http://unlimited6-cl.dps.live/sportinghd/sportinghd.smil/playlist.m3u8
''',
          id: 'paste_sport_pack',
          country: 'International',
          viewers: 3500,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'Real Madrid TV',
          'Sports',
          '''
https://rmtv.akamaized.net/hls/live/2043153/rmtv-es-web/bitrate_3.m3u8
https://rgelive.akamaized.net/hls/live/2043151/radiolive/playlist.m3u8
https://rgelive.akamaized.net/hls/live/2043095/live3/playlist.m3u8
''',
          id: 'paste_rmtv',
          country: 'Spain',
          viewers: 8000,
        ),
        ExtraChannels.fromMultiLinkPaste(
          'DD Sports',
          'Sports',
          '''
https://d3qs3d2rkhfqrt.cloudfront.net/out/v1/b17adfe543354fdd8d189b110617cddd/index.m3u8
''',
          id: 'paste_dd_sports2',
          country: 'India',
          viewers: 10000,
        ),
      ];
}
