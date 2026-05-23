import '../models/model.dart';

/// Maps live API matches to channels in the app catalog.
///
/// ─── Root cause fixes vs old version ────────────────────────────────────────
/// 1. match.channel  = broadcaster name ("T Sports"), NOT tournament name.
///    Old code treated it as tournament → all tournament scoring was broken.
/// 2. Nagorik TV lives in category "Bangladesh", not "Sports".
///    Needs explicit cross-category bonus when BD team plays.
/// 3. Brazil / Argentina / France / Germany / Spain / Portugal had zero team
///    aliases → football international matches got score 0.
/// 4. BD channels (T Sports, Nagorik, Toffee) weren't scored highly enough
///    for Bangladesh matches.
/// ─────────────────────────────────────────────────────────────────────────────
class MatchChannelMatcher {
  MatchChannelMatcher._();

  // ══════════════════════════════════════════════════════════════════════════
  // TEAM ALIASES
  // Every abbreviation / nickname your score API might send as teamA/teamB.
  // ══════════════════════════════════════════════════════════════════════════
  static const _aliases = <String, List<String>>{
    // ── Cricket + Football national ──────────────────────────────────────────
    'bangladesh': ['bangladesh', 'bd', 'ban', 'tigers', 'bengal'],
    'pakistan': ['pakistan', 'pak', 'green shirts'],
    'india': ['india', 'ind', 'bharat'],
    'england': ['england', 'eng'],
    'australia': ['australia', 'aus', 'baggy greens'],
    'sri lanka': ['sri lanka', 'sl', 'lanka'],
    'new zealand': ['new zealand', 'nz', 'blackcaps'],
    'south africa': ['south africa', 'sa', 'rsa', 'proteas'],
    'afghanistan': ['afghanistan', 'afg'],
    'west indies': ['west indies', 'wi', 'windies'],
    'zimbabwe': ['zimbabwe', 'zim'],
    'ireland': ['ireland', 'ire'],
    // ── Football – global nations ────────────────────────────────────────────
    'brazil': ['brazil', 'brasil', 'bra', 'selecao'],
    'argentina': ['argentina', 'arg', 'albiceleste'],
    'france': ['france', 'fra', 'les bleus'],
    'germany': ['germany', 'ger', 'deutschland'],
    'spain': ['spain', 'esp', 'espana', 'la roja'],
    'portugal': ['portugal', 'por'],
    'italy': ['italy', 'ita', 'italia', 'azzurri'],
    'netherlands': ['netherlands', 'ned', 'holland', 'oranje'],
    'croatia': ['croatia', 'cro'],
    'morocco': ['morocco', 'mar'],
    'japan': ['japan', 'jpn'],
    'usa': ['usa', 'united states', 'usmnt'],
    'mexico': ['mexico', 'mex'],
    'uruguay': ['uruguay', 'uru'],
    'colombia': ['colombia', 'col'],
    'chile': ['chile', 'chi'],
    'senegal': ['senegal', 'sen'],
    'nigeria': ['nigeria', 'nga'],
    'ghana': ['ghana', 'gha'],
    'egypt': ['egypt', 'egy'],
    'saudi arabia': ['saudi arabia', 'ksa'],
    'iran': ['iran', 'iri'],
    'south korea': ['south korea', 'korea', 'kor'],
    'denmark': ['denmark', 'den'],
    'switzerland': ['switzerland', 'sui'],
    'belgium': ['belgium', 'bel'],
    'poland': ['poland', 'pol'],
    'sweden': ['sweden', 'swe'],
    'norway': ['norway', 'nor'],
    'wales': ['wales', 'wal'],
    // ── Club sides ───────────────────────────────────────────────────────────
    'arsenal': ['arsenal'],
    'chelsea': ['chelsea'],
    'manchester city': ['manchester city', 'man city'],
    'manchester united': ['manchester united', 'man utd', 'man united'],
    'liverpool': ['liverpool'],
    'tottenham': ['tottenham', 'spurs'],
    'real madrid': ['real madrid', 'real', 'madrid'],
    'barcelona': ['barcelona', 'barca', 'fcb'],
    'atletico madrid': ['atletico madrid', 'atletico'],
    'psg': ['psg', 'paris saint', 'paris'],
    'bayern': ['bayern', 'munich'],
    'dortmund': ['dortmund', 'bvb'],
    'juventus': ['juventus', 'juve'],
    'inter milan': ['inter milan', 'inter'],
    'ac milan': ['ac milan', 'milan'],
    'napoli': ['napoli'],
    // ── Bangladesh football clubs ────────────────────────────────────────────
    'bashundhara': ['bashundhara', 'bksp', 'bsk'],
    'mohammedan': ['mohammedan'],
    'abahani': ['abahani'],
    'sheikh russel': ['sheikh russel', 'russel'],
    'rahmatganj': ['rahmatganj'],
  };

  // ══════════════════════════════════════════════════════════════════════════
  // PLAYER → CHANNEL KEYWORDS
  // If a player name appears in teamA/teamB (solo matches, tennis etc.),
  // these channel keywords get boosted.
  // ══════════════════════════════════════════════════════════════════════════
  static const _playerChannels = <String, List<String>>{
    // Football
    'messi': ['bein', 'fox sports'],
    'ronaldo': ['bein', 'fox sports'],
    'neymar': ['bein', 'fox sports', 't sports', 'tsports'],
    'mbappe': ['bein', 'fox sports'],
    'haaland': ['bein', 'tnt sports'],
    'salah': ['bein', 'tnt sports'],
    'kane': ['sky sports', 'tnt sports'],
    'vini': ['bein', 'fox sports'],
    'vinicius': ['bein', 'fox sports'],
    'modric': ['bein', 'fox sports'],
    // Cricket
    'shakib': ['t sports', 'tsports', 'toffee'],
    'tamim': ['t sports', 'tsports', 'toffee'],
    'mushfiqur': ['t sports', 'tsports'],
    'mahmudullah': ['t sports', 'tsports'],
    'litton': ['t sports', 'tsports'],
    'kohli': ['star sports', 'fancode'],
    'rohit': ['star sports', 'fancode'],
    'bumrah': ['star sports', 'fancode'],
    'babar': ['ptv sports', 'a sports'],
    'rizwan': ['ptv sports', 'a sports'],
    // Tennis
    'djokovic': ['eurosport', 'sky sports tennis', 'bein'],
    'alcaraz': ['eurosport', 'sky sports tennis', 'bein'],
    'swiatek': ['eurosport', 'sky sports tennis'],
  };

  // ══════════════════════════════════════════════════════════════════════════
  // TOURNAMENT → PREFERRED CHANNEL KEYWORDS
  // Matched against the lowercased channel name/show/category blob.
  // Keys are matched with String.contains in both directions.
  // ══════════════════════════════════════════════════════════════════════════
  static const _tournamentChannels = <String, List<String>>{
    // Cricket
    'ipl': ['star sports', 'star', 'fancode', 'hotstar', 'jio'],
    'bpl': [
      't sports',
      'tsports',
      'nagorik',
      'toffee',
      'gazi',
      'sony ten cricket'
    ],
    'cpl': ['star sports', 'espn'],
    'psl': ['ptv sports', 'a sports', 'geo', 'sony'],
    'bbl': ['fox sports'],
    'asia cup': [
      'star sports',
      'star',
      'sony',
      't sports',
      'tsports',
      'toffee'
    ],
    'icc world cup': [
      'star sports',
      'star',
      'sony',
      't sports',
      'tsports',
      'toffee',
      'sky sports cricket',
      'willow'
    ],
    'wtc': ['star sports', 'sony', 'sky sports cricket'],
    'test': [
      'star sports',
      'sony',
      'sky sports cricket',
      'willow',
      't sports',
      'tsports',
      'ptv sports',
      'a sports'
    ],
    'odi': ['star sports', 'sony', 't sports', 'tsports', 'toffee', 'willow'],
    't20i': ['star sports', 'sony', 't sports', 'tsports', 'toffee'],
    // Football
    'fifa world cup': [
      'bein sports',
      'bein',
      'fox sports',
      't sports',
      'tsports',
      'toffee sports',
      'toffee',
      'sony sports',
      'sony ten'
    ],
    'champions league': [
      'tnt sports',
      'bein sports',
      'bein',
      'sony sports',
      't sports',
      'tsports'
    ],
    'europa league': ['tnt sports', 'bein sports', 'bein', 'sony sports'],
    'conference league': ['tnt sports', 'bein'],
    'premier league': [
      'sky sports epl',
      'sky sports football',
      'sky sports',
      'tnt sports',
      't sports',
      'tsports',
      'toffee'
    ],
    'la liga': ['bein sports', 'bein', 'espn'],
    'serie a': ['bein sports', 'bein', 'espn'],
    'bundesliga': ['bein sports', 'bein', 'sky sports'],
    'ligue 1': ['bein sports', 'bein'],
    'copa america': [
      'bein sports',
      'bein',
      'fox sports',
      't sports',
      'tsports',
      'toffee'
    ],
    'euro': ['bein sports', 'bein', 't sports', 'tsports', 'toffee'],
    'afcon': ['bein sports', 'bein', 't sports'],
    'afc championship': [
      'star sports',
      'sony',
      't sports',
      'tsports',
      'toffee'
    ],
    'bfl': ['t sports', 'tsports', 'toffee', 'nagorik', 'gazi'],
    // Other sports
    'tennis': ['sky sports tennis', 'eurosport', 'bein'],
    'formula 1': ['sky sports', 'espn', 'fox sports'],
    'boxing': ['sky sports', 'tnt sports', 'espn', 'fox sports'],
    'basketball': ['espn', 'tnt sports', 'fox sports'],
    'nba': ['espn', 'tnt sports'],
    'golf': ['sky sports golf', 'eurosport', 'fox sports'],
  };

  // ── Fixture-style channel name: "Bangladesh vs Pakistan" ─────────────────
  static final _fixtureRx = RegExp(
    r'^(.+?)\s+vs?\.?\s+(.+)$',
    caseSensitive: false,
  );

  // ── Numbered event feed: "BFL Live 2", "EPL Channel 3" ───────────────────
  static final _numberedFeedRx = RegExp(
    r'(bfl|bpl|epl|ucl|ipl|psl|cpl|match|live|sports?)\s*(?:channel|live|hd)?\s*\d+',
    caseSensitive: false,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ══════════════════════════════════════════════════════════════════════════
  static List<ChannelModel> findRelated(
    MatchModel match,
    List<ChannelModel> channels, {
    int limit = 12,
  }) {
    final sport = match.sport.toLowerCase().trim();
    final teamA = match.teamA.toLowerCase().trim();
    final teamB = match.teamB.toLowerCase().trim();
    final teamBlob = '$teamA $teamB';

    // match.channel = broadcaster hint from API e.g. "T Sports", "beIN Sports"
    // NOT a tournament name — this was the root bug in the old code.
    final broadcasterHint = match.channel.toLowerCase().trim();

    // ── Sport flags ────────────────────────────────────────────────────────
    final isCricket = sport.contains('cricket');
    final isFootball = sport.contains('football') || sport.contains('soccer');
    final isTennis = sport.contains('tennis');
    final isF1 = sport.contains('formula') || sport.contains('f1');
    final isBoxing = sport.contains('boxing');
    final isBasketball = sport.contains('basketball');

    // ── Team presence flags ────────────────────────────────────────────────
    final hasBD = _hasTeam(teamBlob, 'bangladesh');
    final hasPak = _hasTeam(teamBlob, 'pakistan');
    final hasIndia = _hasTeam(teamBlob, 'india');
    final hasEngland = _hasTeam(teamBlob, 'england');
    final hasAustralia = _hasTeam(teamBlob, 'australia');
    final hasBrazil = _hasTeam(teamBlob, 'brazil');
    final hasArgentina = _hasTeam(teamBlob, 'argentina');
    final hasFrance = _hasTeam(teamBlob, 'france');
    final hasGermany = _hasTeam(teamBlob, 'germany');
    final hasSpain = _hasTeam(teamBlob, 'spain');
    final hasPortugal = _hasTeam(teamBlob, 'portugal');
    final hasItaly = _hasTeam(teamBlob, 'italy');

    final isMajorIntlFootball = hasBrazil ||
        hasArgentina ||
        hasFrance ||
        hasGermany ||
        hasSpain ||
        hasPortugal ||
        hasItaly;

    // ── Detect tournament from hint + teams ────────────────────────────────
    final tournament = _detectTournament(
      broadcasterHint,
      teamBlob,
      isCricket: isCricket,
      isFootball: isFootball,
    );

    // ── Score each channel ─────────────────────────────────────────────────
    final scored = <ChannelModel, int>{};

    for (final ch in channels) {
      if (ch.streamUrl.isEmpty) continue;

      final name = ch.name.toLowerCase();
      final show = ch.currentShow.toLowerCase();
      final cat = ch.category.toLowerCase();
      final country = ch.country.toLowerCase();
      // Full searchable blob for this channel
      final blob = '$name $show $cat $country';

      var score = 0;

      // ── Rule 1 : Fixture-named channel (highest priority) ────────────────
      // Channel literally named "Bangladesh vs Pakistan"
      final fxMatch = _fixtureRx.firstMatch(name);
      if (fxMatch != null) {
        final sA = fxMatch.group(1)!.trim();
        final sB = fxMatch.group(2)!.trim();
        if (_sidesMatch(sA, sB, match.teamA, match.teamB)) {
          score += 200; // Exact fixture feed
        } else if (_anyTeamInSide(sA, teamBlob) ||
            _anyTeamInSide(sB, teamBlob)) {
          score += 40; // One team matched
        }
      }

      // ── Rule 2 : Numbered event feed ─────────────────────────────────────
      // "BFL Live 2", "EPL Channel 3", "Match 5"
      final feedMatch = _numberedFeedRx.firstMatch(name);
      if (feedMatch != null) {
        final tag = feedMatch.group(1)!.toLowerCase();
        if (_tagFitsTournament(tag, tournament,
            isCricket: isCricket, isFootball: isFootball)) {
          score += 65;
        } else if (tag == 'match' ||
            tag == 'live' ||
            tag == 'sport' ||
            tag == 'sports') {
          score += 20;
        }
      }

      // ── Rule 3 : Broadcaster hint direct match ────────────────────────────
      // If match.channel = "T Sports", boost channels whose name contains "t sports"
      score += _scoreBroadcasterHint(blob, broadcasterHint);

      // ── Rule 4 : Tournament → preferred channel list ──────────────────────
      score += _scoreTournamentMapping(blob, tournament);

      // ── Rule 5 : Sport-specific scoring ───────────────────────────────────
      if (isCricket) {
        score += _scoreCricket(blob);

        // BD match — T Sports, Nagorik, Toffee, Gazi
        if (hasBD) score += _scoreBDMatch(blob, isCricket: true);

        // Pakistan match — PTV, A Sports, Geo
        if (hasPak) {
          if (blob.contains('ptv sports')) score += 50;
          if (blob.contains('a sports')) score += 45;
          if (blob.contains('geo')) score += 30;
          if (blob.contains('sony')) score += 20;
        }

        // India match — Star Sports, Fancode, Sony
        if (hasIndia) {
          if (blob.contains('star sports')) score += 50;
          if (blob.contains('fancode')) score += 45;
          if (blob.contains('sony sports') || blob.contains('sony ten'))
            score += 40;
          if (blob.contains('willow')) score += 30;
        }

        // England match — Sky Sports Cricket, Willow
        if (hasEngland) {
          if (blob.contains('sky sports cricket')) score += 55;
          if (blob.contains('sky sports')) score += 35;
          if (blob.contains('willow')) score += 30;
        }

        // Australia match — Fox Sports
        if (hasAustralia) {
          if (blob.contains('fox sports')) score += 40;
          if (blob.contains('star sports')) score += 25;
        }
      } else if (isFootball) {
        score += _scoreFootball(blob);

        // BD team in football — T Sports, Toffee, Nagorik, Gazi
        if (hasBD) score += _scoreBDMatch(blob, isCricket: false);

        // Major international teams (Brazil, Argentina, France, Germany, Spain etc.)
        // Best on: beIN Sports, FOX Sports, TNT, Sony, T Sports (for BD viewers)
        if (isMajorIntlFootball) {
          if (blob.contains('bein sports') || blob.contains('bein'))
            score += 60;
          if (blob.contains('fox sports')) score += 45;
          if (blob.contains('tnt sports')) score += 40;
          if (blob.contains('sony sports') || blob.contains('sony ten'))
            score += 30;
          if (blob.contains('t sports') || blob.contains('tsports'))
            score += 28;
          if (blob.contains('toffee sports') || blob.contains('toffee'))
            score += 22;
          if (blob.contains('espn')) score += 28;
          if (blob.contains('eurosport') || blob.contains('euro sport'))
            score += 22;
        }

        // England / Premier League clubs — Sky Sports, TNT
        if (hasEngland ||
            _hasTeam(teamBlob, 'arsenal') ||
            _hasTeam(teamBlob, 'chelsea') ||
            _hasTeam(teamBlob, 'manchester city') ||
            _hasTeam(teamBlob, 'manchester united') ||
            _hasTeam(teamBlob, 'liverpool') ||
            _hasTeam(teamBlob, 'tottenham')) {
          if (blob.contains('sky sports epl') ||
              blob.contains('sky sports football')) score += 55;
          if (blob.contains('sky sports main event')) score += 45;
          if (blob.contains('sky sports')) score += 35;
          if (blob.contains('tnt sports')) score += 40;
        }

        // Spanish clubs — beIN Sports
        if (_hasTeam(teamBlob, 'real madrid') ||
            _hasTeam(teamBlob, 'barcelona') ||
            _hasTeam(teamBlob, 'atletico madrid')) {
          if (blob.contains('bein sports') || blob.contains('bein'))
            score += 55;
          if (blob.contains('espn')) score += 30;
        }

        // Bangladesh Football League (BFL) clubs
        if (_hasTeam(teamBlob, 'bashundhara') ||
            _hasTeam(teamBlob, 'mohammedan') ||
            _hasTeam(teamBlob, 'abahani') ||
            _hasTeam(teamBlob, 'sheikh russel') ||
            tournament.contains('bfl')) {
          if (blob.contains('t sports') || blob.contains('tsports'))
            score += 60;
          if (blob.contains('toffee')) score += 45;
          if (blob.contains('nagorik')) score += 35;
          if (blob.contains('gazi')) score += 30;
        }
      } else if (isTennis) {
        if (blob.contains('sky sports tennis') || blob.contains('tennis'))
          score += 65;
        if (blob.contains('eurosport') || blob.contains('euro sport'))
          score += 55;
        if (blob.contains('bein sports') || blob.contains('bein')) score += 35;
        if (blob.contains('espn')) score += 30;
      } else if (isF1) {
        if (blob.contains('sky sports') &&
            (blob.contains('f1') || blob.contains('formula'))) score += 70;
        if (blob.contains('sky sports main event')) score += 50;
        if (blob.contains('sky sports action')) score += 40;
        if (blob.contains('espn')) score += 35;
        if (blob.contains('fox sports')) score += 30;
      } else if (isBoxing) {
        if (blob.contains('sky sports main event') ||
            blob.contains('sky sports action')) score += 60;
        if (blob.contains('sky sports')) score += 45;
        if (blob.contains('tnt sports')) score += 50;
        if (blob.contains('espn')) score += 45;
        if (blob.contains('fox sports')) score += 40;
      } else if (isBasketball) {
        if (blob.contains('espn')) score += 65;
        if (blob.contains('tnt sports')) score += 55;
        if (blob.contains('fox sports')) score += 40;
      }

      // ── Rule 6 : Player-name channel boost ────────────────────────────────
      // e.g. teamA = "Djokovic", teamB = "Alcaraz" → Eurosport boost
      score += _scorePlayerChannels(blob, teamA);
      score += _scorePlayerChannels(blob, teamB);

      // ── Rule 7 : BD channels cross-category bonus ─────────────────────────
      // Nagorik TV (category: Bangladesh) sometimes airs cricket.
      // Without this rule it gets score 0 because it has no sport keywords.
      if ((isCricket && hasBD) || (isFootball && hasBD)) {
        score += _bdCrossCategory(blob);
      }

      // ── Rule 8 : Country boost ────────────────────────────────────────────
      if (hasBD && country == 'bangladesh') score += 18;
      if (hasPak && country == 'pakistan') score += 12;
      if (hasIndia && country == 'india') score += 10;

      if (score > 0) scored[ch] = score;
    }

    // Sort by score desc, then name asc for tie-breaking
    final sorted = scored.entries.toList()
      ..sort((a, b) {
        final s = b.value.compareTo(a.value);
        return s != 0 ? s : a.key.name.compareTo(b.key.name);
      });
    return sorted.take(limit).map((e) => e.key).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOURNAMENT DETECTION
  // Reads both the broadcaster hint (match.channel) and team names.
  // ══════════════════════════════════════════════════════════════════════════
  static String _detectTournament(
    String hint,
    String teams, {
    required bool isCricket,
    required bool isFootball,
  }) {
    final c = '$hint $teams';

    if (isCricket) {
      if (c.contains('ipl')) return 'ipl';
      if (c.contains('bpl')) return 'bpl';
      if (c.contains('psl')) return 'psl';
      if (c.contains('cpl')) return 'cpl';
      if (c.contains('bbl')) return 'bbl';
      if (c.contains('asia cup') || (c.contains('asia') && c.contains('cup')))
        return 'asia cup';
      if (c.contains('world cup') || c.contains('icc') || c.contains('wc'))
        return 'icc world cup';
      if (c.contains('wtc') || c.contains('world test')) return 'wtc';
      if (c.contains('test')) return 'test';
      if (c.contains('odi')) return 'odi';
      if (c.contains('t20')) return 't20i';
    }

    if (isFootball) {
      if (c.contains('world cup') || c.contains('fifa'))
        return 'fifa world cup';
      if (c.contains('champions') || c.contains('ucl'))
        return 'champions league';
      if (c.contains('europa')) return 'europa league';
      if (c.contains('conference')) return 'conference league';
      if (c.contains('premier') || c.contains('epl') || c.contains('eng.1'))
        return 'premier league';
      if (c.contains('la liga') || c.contains('laliga') || c.contains('esp.1'))
        return 'la liga';
      if (c.contains('serie a') || c.contains('ita.1')) return 'serie a';
      if (c.contains('bundesliga') || c.contains('ger.1')) return 'bundesliga';
      if (c.contains('ligue') || c.contains('fra.1')) return 'ligue 1';
      if (c.contains('copa america') || c.contains('copa'))
        return 'copa america';
      if (c.contains('euro') && !c.contains('eurosport')) return 'euro';
      if (c.contains('afcon') || (c.contains('africa') && c.contains('cup')))
        return 'afcon';
      if (c.contains('afc')) return 'afc championship';
      if (c.contains('bfl') ||
          c.contains('bashundhara') ||
          c.contains('mohammedan') ||
          c.contains('abahani')) return 'bfl';
    }

    if (c.contains('tennis') || c.contains('wimbledon') || c.contains('slam'))
      return 'tennis';
    if (c.contains('formula') || c.contains(' f1 ') || c.contains('grand prix'))
      return 'formula 1';
    if (c.contains('boxing') || c.contains('wbc') || c.contains('wba'))
      return 'boxing';
    if (c.contains('nba') || c.contains('basketball')) return 'basketball';
    if (c.contains('golf') || c.contains('masters') || c.contains('open golf'))
      return 'golf';

    return hint; // Raw hint as fallback
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BROADCASTER HINT MATCH
  // If match.channel = "T Sports", channels with "t sports" in their name
  // get a strong boost — this is the clearest signal we have.
  // ══════════════════════════════════════════════════════════════════════════
  static int _scoreBroadcasterHint(String blob, String hint) {
    if (hint.isEmpty) return 0;
    // Exact phrase match is best
    if (blob.contains(hint)) return 50;
    // Token-level partial match (minimum 3-char token to avoid noise)
    final tokens =
        hint.split(RegExp(r'[^a-z0-9]+')).where((t) => t.length >= 3).toList();
    if (tokens.isEmpty) return 0;
    var hits = 0;
    for (final t in tokens) {
      if (blob.contains(t)) hits++;
    }
    if (hits == 0) return 0;
    if (hits >= tokens.length) return 40;
    return 12;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOURNAMENT → CHANNEL MAPPING
  // ══════════════════════════════════════════════════════════════════════════
  static int _scoreTournamentMapping(String blob, String tournament) {
    for (final entry in _tournamentChannels.entries) {
      // Both directions: tournament contains key OR key contains tournament
      if (!tournament.contains(entry.key) && !entry.key.contains(tournament))
        continue;
      for (final kw in entry.value) {
        if (blob.contains(kw)) return 35; // First match wins; no stacking
      }
    }
    return 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SPORT GENERIC SCORING
  // ══════════════════════════════════════════════════════════════════════════

  /// Generic cricket broadcaster keywords — applicable to any cricket match.
  static int _scoreCricket(String blob) {
    const keywords = [
      'star sports',
      'sony sports',
      'sony ten',
      'ten cricket',
      'willow',
      'sky sports cricket',
      't sports',
      'tsports',
      'toffee sports',
      'toffee',
      'ptv sports',
      'a sports',
      'geo super',
      'geo',
      'fancode',
      'eurosport',
      'euro sport',
    ];
    for (final k in keywords) {
      if (blob.contains(k)) return 20;
    }
    if (blob.contains('cricket')) return 15;
    return 0;
  }

  /// Generic football broadcaster keywords — applicable to any football match.
  static int _scoreFootball(String blob) {
    const keywords = [
      'sky sports football',
      'sky sports epl',
      'sky sports main event',
      'tnt sports',
      'bein sports',
      'bein',
      'fox sports',
      'espn',
      'eurosport',
      'euro sport',
      't sports',
      'tsports',
      'toffee sports',
      'toffee',
      'sony sports',
      'sony ten',
      'star sports',
    ];
    for (final k in keywords) {
      if (blob.contains(k)) return 20;
    }
    if (blob.contains('football') || blob.contains('soccer')) return 10;
    return 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BANGLADESH MATCH SCORING
  // Handles BOTH sports + BD general channels (Nagorik, Gazi, BTV)
  // that sometimes broadcast cricket but have category = "Bangladesh".
  // ══════════════════════════════════════════════════════════════════════════
  static int _scoreBDMatch(String blob, {required bool isCricket}) {
    var score = 0;

    // ── Primary BD sports channels ─────────────────────────────────────────
    if (blob.contains('t sports') ||
        blob.contains('tsports') ||
        blob.contains('t-sports')) {
      score += isCricket ? 70 : 60;
    } else if (blob.contains('toffee sports') || blob.contains('toffee')) {
      score += isCricket ? 55 : 45;
    } else if (blob.contains('sony ten cricket') ||
        blob.contains('ten cricket')) {
      score += 50;
    }

    // ── BD general channels — cross-category (Nagorik, Gazi, BTV) ──────────
    // These are in category "Bangladesh", not "Sports", so they score 0
    // without this explicit boost.
    if (blob.contains('nagorik tv') || blob.contains('nagorik')) {
      score += isCricket ? 40 : 30;
    }
    if (blob.contains('gazi tv') || blob.contains('gazi')) {
      score += isCricket ? 35 : 25;
    }
    if (blob.contains('btv') || blob.contains('bangladesh television')) {
      score += isCricket ? 25 : 18;
    }
    if (blob.contains('channel i') || blob.contains('channeli')) {
      score += 15;
    }

    return score;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BD CROSS-CATEGORY BONUS
  // Applied to BD general channels even when _scoreBDMatch is not triggered.
  // Extra safety net so Nagorik TV always appears for BD matches.
  // ══════════════════════════════════════════════════════════════════════════
  static int _bdCrossCategory(String blob) {
    if (blob.contains('nagorik tv') || blob.contains('nagorik')) return 30;
    if (blob.contains('gazi tv') || blob.contains('gazi')) return 25;
    if (blob.contains('btv') || blob.contains('bangladesh television'))
      return 18;
    if (blob.contains('channel i') || blob.contains('channeli')) return 12;
    if (blob.contains('somoy')) return 10;
    if (blob.contains('deepto')) return 8;
    if (blob.contains('bangla vision') || blob.contains('banglavision'))
      return 8;
    return 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PLAYER-NAME CHANNEL BOOST
  // When teamA/teamB is a player name (tennis, boxing, solo events).
  // ══════════════════════════════════════════════════════════════════════════
  static int _scorePlayerChannels(String blob, String nameOrTeam) {
    for (final entry in _playerChannels.entries) {
      if (!nameOrTeam.contains(entry.key)) continue;
      for (final kw in entry.value) {
        if (blob.contains(kw)) return 25;
      }
    }
    return 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FIXTURE / FEED HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static bool _tagFitsTournament(
    String tag,
    String tournament, {
    required bool isCricket,
    required bool isFootball,
  }) {
    switch (tag) {
      case 'bfl':
        return tournament.contains('bfl') ||
            tournament.contains('bangladesh football');
      case 'bpl':
        return isCricket && tournament.contains('bpl');
      case 'epl':
        return tournament.contains('premier') || tournament.contains('epl');
      case 'ipl':
        return isCricket && tournament.contains('ipl');
      case 'psl':
        return isCricket && tournament.contains('psl');
      case 'cpl':
        return isCricket && tournament.contains('cpl');
      case 'ucl':
        return tournament.contains('champion') || tournament.contains('ucl');
      case 'match':
      case 'live':
      case 'sport':
      case 'sports':
        return true;
      default:
        return false;
    }
  }

  /// Both sides of a fixture channel name match the two teams (either order).
  static bool _sidesMatch(String sA, String sB, String teamA, String teamB) {
    final aLo = teamA.toLowerCase();
    final bLo = teamB.toLowerCase();
    return (_sideVsTeam(sA, aLo) && _sideVsTeam(sB, bLo)) ||
        (_sideVsTeam(sA, bLo) && _sideVsTeam(sB, aLo));
  }

  static bool _anyTeamInSide(String side, String teamBlob) {
    for (final t in _expandTokens(side)) {
      if (t.length >= 3 && teamBlob.contains(t)) return true;
    }
    return false;
  }

  static bool _sideVsTeam(String side, String team) {
    final sTokens = _expandTokens(side);
    final tTokens = _expandTokens(team);
    for (final s in sTokens) {
      if (s.length < 2) continue;
      for (final t in tTokens) {
        if (t.length < 2) continue;
        if (s == t || s.contains(t) || t.contains(s)) return true;
      }
    }
    return false;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ══════════════════════════════════════════════════════════════════════════

  /// Expand a raw string into a set of tokens + alias expansions.
  static Set<String> _expandTokens(String raw) {
    final lower = raw.toLowerCase().replaceAll('.', ' ').trim();
    final out = <String>{lower};
    for (final entry in _aliases.entries) {
      if (entry.value.any((a) => lower.contains(a))) {
        out.add(entry.key);
        out.addAll(entry.value);
      }
    }
    for (final part in lower.split(RegExp(r'[\s\-_/]+'))) {
      if (part.isNotEmpty) out.add(part);
    }
    return out;
  }

  /// Check if teamBlob contains any alias for [key].
  static bool _hasTeam(String teamBlob, String key) {
    final list = _aliases[key];
    if (list == null) return teamBlob.contains(key);
    return list.any((a) => teamBlob.contains(a));
  }
}
