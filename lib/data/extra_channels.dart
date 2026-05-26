import '../models/model.dart';
import 'user_paste_channels.dart';

/// Extra / updated channels with multi-link (SD + FHD) from user m3u8 list.
class ExtraChannels {
  ExtraChannels._();

  static const _gp = 'https://owrcovcrpy.gpcdn.net/bpk-tv';
  static const _ip = 'http://198.195.239.50:8095';
  static const _mag =
      'http://mag.king-4k.cc:80/live/C1645263A1D245C/1sFTVBSVCP';

  static ChannelModel _ch(
    String id,
    String name,
    String category,
    String sd, {
    String? fhd,
    List<StreamLink> more = const [],
    String country = 'Bangladesh',
    int viewers = 2500,
    String show = 'Live',
  }) {
    final alts = <StreamLink>[
      if (fhd != null && fhd != sd) StreamLink(url: fhd, label: 'FHD'),
      ...more,
    ];
    return ChannelModel(
      id: id,
      name: name,
      category: category,
      country: country,
      streamUrl: sd,
      isLive: true,
      viewers: viewers,
      currentShow: show,
      alternateStreams: alts,
    );
  }

  /// Add new channels here once — they sync to Categories, Live nav & Sports.
  static List<ChannelModel> get userChannels => [
        fromMultiLinkPaste(
          'AndFlix HD',
          'Movies',
          '''
http://212.102.34.8:9080/AndFlixHD/video.m3u8
http://103.159.180.34:5001/live/562.m3u8
http://63.141.239.226:81/live/cctv1md.m3u8?tm=1779280800&key=c6e9fb42092f7494c6e8142d46271002
http://149.71.34.166:8002/play/a01b/index.m3u8
http://149.71.34.166:8002/play/a017/index.m3u8
''',
          id: 'user_andflix',
        ),
      ];

  /// Paste multiple URLs (one per line) — all links attach to [name] automatically.
  static ChannelModel fromMultiLinkPaste(
    String name,
    String category,
    String rawLinks, {
    String id = '',
    String country = 'India',
    int viewers = 2000,
  }) {
    final urls = rawLinks
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) =>
            l.startsWith('http') || l.startsWith('rtmp') || l.startsWith('rtsp'))
        .toList();
    if (urls.isEmpty) {
      return ChannelModel(
        id: id.isEmpty ? 'user_empty' : id,
        name: name,
        category: category,
        country: country,
        streamUrl: '',
      );
    }
    final alts = <StreamLink>[];
    for (var i = 1; i < urls.length; i++) {
      alts.add(StreamLink(url: urls[i], label: 'Link ${i + 1}'));
    }
    return ChannelModel(
      id: id.isEmpty ? 'user_${_nameKey(name)}' : id,
      name: name,
      category: category,
      country: country,
      streamUrl: urls.first,
      isLive: true,
      viewers: viewers,
      alternateStreams: alts,
    );
  }

  static List<ChannelModel> get all => [
        ...userChannels,
        ...UserPasteChannels.all,
        // ── Star Sports / Sony ─────────────────────────────────────
        _ch(
          'xs1',
          'Star Sports 1',
          'Sports',
          '$_ip/SonyTenSports5/tracks-v1a1/mono.m3u8',
          more: const [
            StreamLink(
              url: 'http://103.161.153.165:8000/play/stp1h/index.m3u8',
              label: 'Alt 2',
            ),
            StreamLink(
              url: 'http://149.71.34.166:8000/play/a01k/index.m3u8',
              label: 'Alt 3',
            ),
          ],
          country: 'India',
          viewers: 18000,
        ),
        fromMultiLinkPaste(
          'Star Sports 1 HD',
          'Sports',
          'http://149.71.34.166:8000/play/a01k/index.m3u8',
          id: 'user_stars1hd',
          country: 'India',
          viewers: 16000,
        ),
        fromMultiLinkPaste(
          'DD Sports',
          'Sports',
          'https://d3qs3d2rkhfqrt.cloudfront.net/out/v1/b17adfe543354fdd8d189b110617cddd/index.m3u8',
          id: 'user_dd_sports',
          country: 'India',
          viewers: 12000,
        ),
        fromMultiLinkPaste(
          'Eurosport HD',
          'Sports',
          'http://103.159.180.34:5001/live/875.m3u8\n'
          'http://151.80.18.177:86/Eurosport_HD/index.m3u8',
          id: 'user_eurosport_hd',
          country: 'UK',
          viewers: 9000,
        ),
        _ch(
          'xs_ts2',
          'T Sports 2',
          'Sports',
          '$_mag/756462.m3u8',
          country: 'Bangladesh',
          viewers: 14000,
          show: 'Live Cricket',
        ),
        _ch(
          'xs_nag_sport',
          'Nagorik TV',
          'Sports',
          '$_ip/nagorik/tracks-v1a1/mono.m3u8',
          more: const [
            StreamLink(
              url: 'https://owrcovcrpy.gpcdn.net/bpk-tv/1718/output/index.m3u8',
              label: 'GP CDN',
            ),
          ],
          country: 'Bangladesh',
          viewers: 9000,
          show: 'Live Sports',
        ),
        _ch(
          'xs2',
          'SONY MAX HD',
          'Movies',
          '$_ip/SonyMAX/tracks-v1a1/mono.m3u8',
          country: 'India',
          viewers: 9000,
        ),

        // ── Bangladesh (gpcdn SD + FHD) ───────────────────────────
        _ch('xb_aj', 'Al Jazeera', 'English',
            '$_gp/1721/output/index.m3u8',
            country: 'Qatar', viewers: 5500, show: 'World News'),
        _ch('xb_btv', 'BTV', 'Bangladesh', '$_gp/1709/output/index.m3u8',
            fhd:
                '$_gp/1709/output/1709-audio_113392_eng=113200-video=1692000.m3u8',
            more: const [
              StreamLink(
                url: '$_ip/BTV/tracks-v1a1/mono.m3u8',
                label: 'Server 2',
              ),
            ]),
        _ch('xb_jam', 'Jamuna TV', 'Bangladesh',
            '$_gp/1701/output/index.m3u8',
            fhd:
                '$_gp/1701/output/1701-audio_113312_eng=113200-video=1692000.m3u8'),
        _ch('xb_71', '71 TV', 'Bangladesh', '$_gp/1705/output/index.m3u8',
            fhd:
                '$_gp/1705/output/1705-audio_113352_eng=113200-video=1692000.m3u8'),
        _ch('xb_sn', 'Star News BD', 'Bangladesh',
            '$_gp/1710/output/index.m3u8'),
        _ch('xb_c24', 'Channel 24', 'Bangladesh',
            '$_gp/1703/output/index.m3u8',
            fhd:
                '$_gp/1703/output/1703-audio_113332_eng=113200-video=1692000.m3u8'),
        _ch('xb_som', 'Somoy TV', 'Bangladesh',
            '$_gp/1702/output/index.m3u8',
            fhd:
                '$_gp/1702/output/1702-audio_113322_eng=113200-video=1692000.m3u8'),
        _ch('xb_dbc', 'DBC News', 'Bangladesh',
            '$_gp/1728/output/index.m3u8'),
        _ch('xb_ind', 'Independent TV', 'Bangladesh',
            '$_gp/1704/output/index.m3u8',
            fhd:
                '$_gp/1704/output/1704-audio_113342_eng=113200-video=1692000.m3u8'),
        _ch('xb_ekh', 'Ekhon TV', 'Bangladesh',
            '$_gp/1713/output/index.m3u8'),
        _ch('xb_n24', 'News24 BD', 'Bangladesh',
            '$_gp/1708/output/index.m3u8',
            more: const [
              StreamLink(
                url: '$_ip/News24/tracks-v1a1/mono.m3u8',
                label: 'Server 2',
              ),
            ]),
        _ch('xb_mas', 'Masranga TV', 'Bangladesh',
            '$_gp/1722/output/index.m3u8',
            fhd:
                '$_gp/1722/output/1722-audio_113522_eng=113200-video=1692000.m3u8'),
        _ch('xb_ci', 'Channel i', 'Bangladesh',
            '$_gp/1723/output/index.m3u8',
            fhd:
                '$_gp/1723/output/1723-audio_113532_eng=113200-video=1692000.m3u8'),
        _ch('xb_ntv', 'NTV', 'Bangladesh', '$_gp/1716/output/index.m3u8',
            fhd:
                '$_gp/1716/output/1716-audio_113462_eng=113200-video=1692000.m3u8'),
        _ch('xb_bv', 'Bangla Vision', 'Bangladesh',
            '$_gp/1715/output/index.m3u8',
            fhd:
                '$_gp/1715/output/1715-audio_113452_eng=113200-video=1692000.m3u8'),
        _ch('xb_dip', 'Deepto TV', 'Bangladesh',
            '$_gp/1711/output/index.m3u8',
            fhd:
                '$_gp/1711/output/1711-audio_113412_eng=113200-video=1692000.m3u8'),
        _ch('xb_c9', 'Channel 9', 'Bangladesh',
            '$_gp/1729/output/index.m3u8'),
        _ch('xb_sat', 'SATV', 'Bangladesh', '$_gp/1720/output/index.m3u8'),
        _ch('xb_isl', 'Islamic TV', 'Bangladesh',
            '$_gp/1724/output/index.m3u8'),
        _ch('xb_nag', 'Nagorik TV', 'Bangladesh',
            '$_gp/1718/output/index.m3u8',
            more: const [
              StreamLink(
                url: '$_ip/nagorik/tracks-v1a1/mono.m3u8',
                label: 'Server 2',
              ),
            ]),

        // ── Bangladesh (King-4K MAG — multi-link via merge) ─────────
        _ch('xmag_bdtv', 'Bangladesh TV', 'Bangladesh', '$_mag/108810.m3u8'),
        _ch('xmag_atnb', 'ATN Bangla', 'Bangladesh', '$_mag/108790.m3u8'),
        _ch('xmag_atnn', 'ATN News', 'Bangladesh', '$_mag/108792.m3u8'),
        _ch('xmag_btvw', 'BTV World', 'Bangladesh', '$_mag/108800.m3u8'),
        _ch('xmag_bijoy', 'Bijoy TV', 'Bangladesh', '$_mag/108797.m3u8'),
        _ch('xmag_colb', 'Colors Bangla', 'Bangladesh', '$_mag/108807.m3u8'),
        _ch('xmag_colbhd', 'Colors Bangla HD', 'Bangladesh',
            '$_mag/108781.m3u8'),
        _ch('xmag_ddb', 'DD Bangla', 'Bangladesh', '$_mag/108809.m3u8'),
        _ch('xmag_dhoom', 'Dhoom Music', 'Bangladesh', '$_mag/108813.m3u8'),
        _ch('xmag_jalsha', 'Jalsha Movies', 'Movies', '$_mag/108783.m3u8'),
        _ch('xmag_madani', 'Madani TV', 'Bangladesh', '$_mag/108866.m3u8'),
        _ch('xmag_mohona', 'Mohona TV', 'Bangladesh', '$_mag/108824.m3u8'),
        _ch('xmag_n18', 'News18 Bangla', 'Bangladesh', '$_mag/108838.m3u8'),
        _ch('xmag_rtv', 'RTV', 'Bangladesh', '$_mag/108833.m3u8'),
        _ch('xmag_sonya', 'Sony Aath', 'Entertainment', '$_mag/108839.m3u8'),
        _ch('xmag_sjhd', 'Star Jalsha HD', 'Entertainment',
            '$_mag/108868.m3u8'),
        _ch('xmag_sjm', 'Star Jalsha Movies', 'Movies', '$_mag/1458372.m3u8'),
        _ch('xmag_ananda', 'Ananda TV', 'Bangladesh', '$_mag/108878.m3u8'),
        _ch('xmag_sun', 'Sun Bangla', 'Bangladesh', '$_mag/126098.m3u8'),
        _ch('xmag_ts2', 'T-Sports 2', 'Sports', '$_mag/756462.m3u8'),
        _ch('xmag_iqra', 'Iqra TV Bangla', 'Bangladesh', '$_mag/1440967.m3u8'),
        _ch('xmag_rep', 'Republic Bangla', 'Bangladesh', '$_mag/1440978.m3u8'),
        _ch('xmag_asian', 'Asian TV', 'Bangladesh', '$_mag/1440997.m3u8'),
        _ch('xmag_ekushey', 'Ekushey TV', 'Bangladesh', '$_mag/1441003.m3u8'),
        _ch('xmag_sangeet', 'Sangeet Bangla', 'Entertainment',
            '$_mag/1458371.m3u8'),
        _ch('xmag_zbhd', 'Zee Bangla HD', 'Entertainment', '$_mag/108860.m3u8'),
        _ch('xmag_zbc', 'Zee Bangla Cinema', 'Movies', '$_mag/108845.m3u8'),
        _ch('xmag_natgeo', 'Nat Geo HD', 'English', '$_mag/63557.m3u8'),
        _ch('xmag_24g', '24 Ghanta', 'Bangladesh', '$_mag/112574.m3u8'),
        _ch('xmag_abp', 'ABP Ananda', 'Bangladesh', '$_mag/112573.m3u8'),
        _ch('xmag_tv9', 'TV9 Bangla', 'Bangladesh', '$_mag/1441548.m3u8'),
        _ch('xmag_n24hd', 'News 24 HD', 'Bangladesh', '$_mag/108849.m3u8',
            more: const [
              StreamLink(
                url: '$_gp/1708/output/index.m3u8',
                label: 'GP CDN',
              ),
            ]),
        _ch('xmag_btv', 'BTV', 'Bangladesh', '$_mag/108801.m3u8',
            more: const [
              StreamLink(
                url: '$_gp/1709/output/index.m3u8',
                label: 'GP CDN',
              ),
            ]),
        _ch('xmag_c9', 'Channel 9', 'Bangladesh', '$_mag/108803.m3u8'),
        _ch('xmag_ci', 'Channel I', 'Bangladesh', '$_mag/108805.m3u8'),
        _ch('xmag_dbc', 'DBC News', 'Bangladesh', '$_mag/108808.m3u8'),
        _ch('xmag_ind', 'Independent TV', 'Bangladesh', '$_mag/108819.m3u8'),
        _ch('xmag_jam', 'Jamuna TV', 'Bangladesh', '$_mag/108853.m3u8'),
        _ch('xmag_ntv', 'NTV', 'Bangladesh', '$_mag/108830.m3u8'),
        _ch('xmag_satv', 'SATV', 'Bangladesh', '$_mag/108836.m3u8'),
        _ch('xmag_bv', 'Bangla Vision', 'Bangladesh', '$_mag/1441001.m3u8'),
        _ch('xmag_zb', 'Zee Bangla', 'Entertainment', '$_mag/108850.m3u8'),
        _ch('xmag_ent10', 'Enter 10 Bangla', 'Entertainment',
            '$_mag/126105.m3u8'),

        // ── Other channels ─────────────────────────────────────────
        _ch('xo1', 'Green TV', 'Bangladesh',
            'https://app.ncare.live/streams/greentv.stream/playlist.m3u8'),
        _ch('xo2', 'Movie Bangla', 'Movies',
            'http://alvetv.com/moviebanglatv/8080/index.m3u8'),
        _ch('xo3', 'Zee Cinema HD', 'Hindi',
            'http://103.159.180.34:5001/live/165.m3u8',
            country: 'India'),
        _ch('xo4', '& Pictures', 'Hindi',
            'http://103.159.180.34:5001/live/185.m3u8',
            country: 'India'),
        _ch('xo5', 'Cartoon Network', 'Kids',
            'http://103.159.180.34:5001/live/166.m3u8',
            country: 'India'),
        _ch('xo6', 'Zee Bangla', 'Entertainment',
            'http://103.159.180.34:5001/live/625.m3u8',
            country: 'India'),
        _ch('xo7', 'Zee Bangla Cinema', 'Movies',
            'http://103.159.180.34:5001/live/3476.m3u8',
            country: 'India'),
        _ch('xo8', 'Enter10 Bangla', 'Entertainment',
            'https://live-bangla.akamaized.net/liveabr/pub-iobanglakp3sff/live_720p/chunks.m3u8'),
        _ch('xo9', 'Discovery', 'English',
            'https://mumbai-edge.smartplaytv.in/Discovery/index.m3u8'),
        _ch('xo10', 'Discovery Bangla', 'Bangladesh',
            'http://103.159.180.34:5001/live/573.m3u8'),
        _ch('xo11', 'Animal Planet', 'English',
            'http://103.159.180.34:5001/live/286.m3u8',
            country: 'India'),
        _ch('xo12', 'Animal Planet Hindi', 'Hindi',
            'http://103.159.180.34:5001/live/566.m3u8',
            country: 'India'),
        _ch('xo13', 'Travel XP', 'English',
            'http://103.159.180.34:5001/live/164.m3u8',
            country: 'India'),
        _ch('xo13b', 'Zee TV', 'Entertainment',
            'http://103.159.180.34:5001/live/167.m3u8',
            country: 'India'),
        _ch('xo13c', 'Music India', 'Entertainment',
            'http://103.159.180.34:5001/live/250.m3u8',
            country: 'India'),
        _ch('xo14', 'Zing', 'Entertainment',
            'http://103.159.180.34:5001/live/585.m3u8',
            country: 'India'),
        _ch('xo15', 'Deshi TV', 'Bangladesh',
            'https://deshitv.deshitv24.net/live/myStream/playlist.m3u8'),
        _ch('xo16', 'Me TV', 'Bangladesh',
            'https://iptvbd.live/metv1080/1080.m3u8'),
        _ch('xo17', 'YRF Music', 'Entertainment',
            'https://cdn-uw2-prod.tsv2.amagi.tv/linear/amg01412-xiaomiasia-yrfmusic-xiaomi/playlist.m3u8'),
        _ch('xo18', 'Aaj Tak', 'Hindi',
            'https://aajtaklive-amd.akamaized.net/hls/live/2014416/aajtak/aajtaklive/live_404p/chunks.m3u8',
            country: 'India', viewers: 8000),
        _ch('xo19', 'Dangal', 'Hindi',
            'https://live-dangal.akamaized.net/liveabr/playlist.m3u8',
            country: 'India'),
        _ch('xo20', 'CNN International', 'English',
            'https://amg01448-samsungin-cnnnow-samsungin-4npqg.amagi.tv/playlist/amg01448-samsungin-cnnnow-samsungin/playlist.m3u8'),
        _ch('xo21', 'DD National', 'Hindi',
            'https://d3qs3d2rkhfqrt.cloudfront.net/out/v1/40492a64c1db4a1385ba1a397d357d3a/index.m3u8',
            country: 'India'),
        _ch('xo22', 'Colors Bangla Cinema', 'Movies',
            '$_ip/ColorsBanglaChinema/tracks-v1a1/mono.m3u8'),
        _ch('xo23', 'Zee Bangla Cinema', 'Movies',
            '$_ip/ZeeBanglaCinema/tracks-v1a1/mono.m3u8',
            country: 'India'),
      ];

  /// Merge [extra] into [base] by channel name (keeps more links).
  static String _nameKey(String name) {
    final n = name.toLowerCase().trim();
    switch (n) {
      case 'ekkator tv':
        return '71 tv';
      case 'sangshad tv':
        return 'ekhon tv';
      case 'news24 bangladesh':
      case 'news 24 hd':
        return 'news24 bd';
      case 'ekushey television':
        return 'ekushey tv';
      case 'enter10 bangla':
        return 'enter 10 bangla';
      case 'sony sports ten 1 hd (toffee)':
        return 'sony sports ten 1 hd';
      case 'sony sports ten 2 hd (toffee)':
        return 'sony sports ten 2 hd';
      case 'sony sports ten 5 hd (toffee)':
        return 'sony sports ten 5 hd';
      case 'sony ten cricket (toffee)':
        return 'sony ten cricket';
      case 'euro sport hd (toffee)':
        return 'euro sport hd';
      case 'cnn vip':
        return 'cnn international';
      case 'ekattor tv':
        return 'ekhon tv';
      case 'zee bangla cinema vip':
        return 'zee bangla cinema';
      case 'sony aat vip':
        return 'sony aath';
      default:
        return n;
    }
  }

  static List<ChannelModel> merge(
    List<ChannelModel> base,
    List<ChannelModel> extra,
  ) {
    final byName = <String, ChannelModel>{};
    for (final c in base) {
      byName[_nameKey(c.name)] = c;
    }
    for (final c in extra) {
      final key = _nameKey(c.name);
      final prev = byName[key];
      if (prev == null) {
        byName[key] = c;
      } else {
        byName[key] = _mergeLinks(prev, c);
      }
    }
    return byName.values.toList();
  }

  static ChannelModel _mergeLinks(ChannelModel a, ChannelModel b) {
    final seen = <String>{};
    final links = <StreamLink>[];
    for (final l in [...a.allStreams, ...b.allStreams]) {
      if (seen.add(l.url)) links.add(_labelledLink(l));
    }
    if (links.isEmpty) return a;
    final primary = links.first;
    return ChannelModel(
      id: a.id,
      name: a.name,
      category: b.category.isNotEmpty ? b.category : a.category,
      country: a.country,
      streamUrl: primary.url,
      logoUrl: a.logoUrl.isNotEmpty ? a.logoUrl : b.logoUrl,
      isLive: a.isLive || b.isLive,
      viewers: a.viewers > b.viewers ? a.viewers : b.viewers,
      currentShow: a.currentShow.isNotEmpty ? a.currentShow : b.currentShow,
      headers: primary.headers,
      alternateStreams: links.length > 1 ? links.sublist(1) : [],
    );
  }

  static StreamLink _labelledLink(StreamLink link) {
    if (link.label != 'Link' && link.label != 'SD') return link;
    final u = link.url.toLowerCase();
    if (u.contains('toffeelive.com')) {
      return StreamLink(url: link.url, label: 'TOFFEE', headers: link.headers);
    }
    if (u.contains('gpcdn.net')) {
      return StreamLink(url: link.url, label: 'GP CDN', headers: link.headers);
    }
    if (u.contains('king-4k.cc') || u.contains('mag.')) {
      return StreamLink(url: link.url, label: 'MAG', headers: link.headers);
    }
    if (u.contains('198.195.239.50')) {
      return StreamLink(url: link.url, label: 'ALT', headers: link.headers);
    }
    return link;
  }
}
