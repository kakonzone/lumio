import 'dart:math';

class FingerprintRandomizer {
  FingerprintRandomizer._();
  static final _rng = Random.secure();

  // Expanded UA pool — 80+ real Chrome-on-Android strings (Android 10-14)
  static const _uaPool = <String>[
    // Pixel devices
    'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; Pixel 6 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; Pixel 4a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; Pixel 3 XL) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36',
    // Samsung Galaxy S series
    'Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-S906B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; SM-S906B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; SM-S906B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; SM-G970F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    // Samsung Galaxy A series
    'Mozilla/5.0 (Linux; Android 14; SM-A556B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; SM-A546B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-A536B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-A525F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-A515F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; SM-A525F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; SM-A505F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; SM-A505FN) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; SM-A505F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; SM-A205G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    // Xiaomi Redmi
    'Mozilla/5.0 (Linux; Android 14; M2404J19PG) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; 23046PNC9G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; 23021RAAEG) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; 2201117SY) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; 2201117TG) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; M2007J20SY) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; M2007J20CI) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; M2006C3MG) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; M2004J19C) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; M2003J15SC) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
    // Oppo
    'Mozilla/5.0 (Linux; Android 14; CPH2583) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; CPH2511) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; CPH2451) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; CPH2449) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; CPH2365) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; CPH2235) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; CPH2127) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; CPH2095) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; CPH2043) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; CPH2007) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    // Vivo
    'Mozilla/5.0 (Linux; Android 14; V2334A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; V2318A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; V2243A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; V2231A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; V2154A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; V2135A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; V2045A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; V2039A) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; V2027) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; V1938T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    // Realme
    'Mozilla/5.0 (Linux; Android 14; RMX3890) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; RMX3889) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; RMX3761) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; RMX3686) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; RMX3571) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; RMX3471) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; RMX3231) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; RMX3191) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; RMX3085) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; RMX3063) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    // OnePlus
    'Mozilla/5.0 (Linux; Android 14; CPH2611) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; CPH2609) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; CPH2513) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; CPH2447) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; CPH2381) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; CPH2359) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; CPH2271) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; CPH2269) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; CPH2171) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; CPH2123) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    // Motorola
    'Mozilla/5.0 (Linux; Android 14; motorola edge 40) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; motorola edge 30) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; motorola edge 30 fusion) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; moto g82) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; motorola edge 20) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; moto g52) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; motorola one 5G ace) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; motorola one action) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 10; moto g8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36',
  ];

  static String randomUserAgent() => _uaPool[_rng.nextInt(_uaPool.length)];

  // Real device screen matrix with matching devicePixelRatio
  static const _screenMatrix = <({int width, int height, double dpr})>[
    (width: 360, height: 800, dpr: 2.625),
    (width: 393, height: 873, dpr: 2.75),
    (width: 412, height: 915, dpr: 3.0),
    (width: 384, height: 854, dpr: 2.75),
    (width: 360, height: 780, dpr: 2.625),
    (width: 375, height: 812, dpr: 3.0),
    (width: 390, height: 844, dpr: 3.0),
    (width: 414, height: 896, dpr: 3.0),
    (width: 393, height: 851, dpr: 2.625),
    (width: 411, height: 823, dpr: 2.625),
  ];

  static ({int width, int height, double dpr}) randomScreen() {
    return _screenMatrix[_rng.nextInt(_screenMatrix.length)];
  }

  static (int, int) randomViewport() {
    final screen = randomScreen();
    return (screen.width, screen.height);
  }

  static double randomDevicePixelRatio() {
    final screen = randomScreen();
    return screen.dpr;
  }

  // Weighted timezone — match install region (South Asia focus)
  static const _timezones = <(String tz, int weight)>[
    ('Asia/Kolkata', 40), // IST
    ('Asia/Dhaka', 25), // BST
    ('Asia/Karachi', 20), // PKT
    ('Asia/Colombo', 10), // IST
    ('Asia/Kathmandu', 5), // NPT
  ];

  static String randomTimezone() {
    final totalWeight = _timezones.fold<int>(0, (sum, item) => sum + item.$2);
    var random = _rng.nextInt(totalWeight);
    for (final (tz, weight) in _timezones) {
      random -= weight;
      if (random < 0) return tz;
    }
    return _timezones.first.$1;
  }

  // Weighted language
  static const _languages = <(String lang, int weight)>[
    ('en-IN', 35),
    ('bn-BD', 25),
    ('hi-IN', 20),
    ('ur-PK', 15),
    ('en-US', 5),
  ];

  static String randomLanguage() {
    final totalWeight = _languages.fold<int>(0, (sum, item) => sum + item.$2);
    var random = _rng.nextInt(totalWeight);
    for (final (lang, weight) in _languages) {
      random -= weight;
      if (random < 0) return lang;
    }
    return _languages.first.$1;
  }

  static List<String> randomLanguages() {
    final primary = randomLanguage();
    final secondary = primary.contains('-') ? primary.split('-').first : 'en';
    return [primary, secondary];
  }

  // Hardware specs
  static int randomHardwareConcurrency() {
    const cores = [4, 6, 8];
    final weights = [0.4, 0.35, 0.25];
    final rand = _rng.nextDouble();
    if (rand < weights[0]) return cores[0];
    if (rand < weights[0] + weights[1]) return cores[1];
    return cores[2];
  }

  static int randomDeviceMemory() {
    const memory = [3, 4, 6, 8];
    final weights = [0.2, 0.4, 0.25, 0.15];
    final rand = _rng.nextDouble();
    if (rand < weights[0]) return memory[0];
    if (rand < weights[0] + weights[1]) return memory[1];
    if (rand < weights[0] + weights[1] + weights[2]) return memory[2];
    return memory[3];
  }

  static String randomConnectionType() {
    // 85% 4g, 15% 3g
    return _rng.nextDouble() < 0.85 ? '4g' : '3g';
  }

  // Math.random seed perturbation
  static String randomSeedJs() {
    final seed = _rng.nextInt(1000000);
    return '''
(function(){
  var _originalMath = Math;
  var seed = $seed;
  Math.random = function() {
    var x = Math.sin(seed++) * 10000;
    return x - Math.floor(x);
  };
  Math.random._seed = seed;
})();
''';
  }

  // Anti-detection JS — navigator.webdriver override, chrome.runtime removal, plugins spoofing
  static String antiDetectionJs() {
    final timezone = randomTimezone();
    final languages = randomLanguages();
    final hwConcurrency = randomHardwareConcurrency();
    final deviceMemory = randomDeviceMemory();
    final connectionType = randomConnectionType();
    
    return '''
(function(){
  // navigator.webdriver override
  Object.defineProperty(navigator, 'webdriver', {
    get: function() { return undefined; }
  });
  
  // Remove chrome.runtime
  if (window.chrome && window.chrome.runtime) {
    delete window.chrome.runtime;
  }
  
  // Spoof plugins array (real mobile Chrome has empty plugins)
  Object.defineProperty(navigator, 'plugins', {
    get: function() { return []; }
  });
  
  // Spoof languages
  Object.defineProperty(navigator, 'languages', {
    get: function() { return ${languages.toString()}; }
  });
  
  // Add hardware specs
  Object.defineProperty(navigator, 'hardwareConcurrency', {
    get: function() { return $hwConcurrency; }
  });
  
  Object.defineProperty(navigator, 'deviceMemory', {
    get: function() { return $deviceMemory; }
  });
  
  // Connection type
  if (navigator.connection) {
    Object.defineProperty(navigator.connection, 'effectiveType', {
      get: function() { return '$connectionType'; }
    });
  }
  
  // Timezone spoof
  var originalGetTimezoneOffset = Date.prototype.getTimezoneOffset;
  Date.prototype.getTimezoneOffset = function() {
    // Offset for $timezone
    var offsets = {
      'Asia/Kolkata': -330,
      'Asia/Dhaka': -360,
      'Asia/Karachi': -300,
      'Asia/Colombo': -330,
      'Asia/Kathmandu': -345
    };
    return offsets['$timezone'] || originalGetTimezoneOffset.call(this);
  };
  
  // Chrome object spoof (minimal)
  if (!window.chrome) {
    window.chrome = {};
  }
  if (!window.chrome.runtime) {
    window.chrome.runtime = {};
  }
})();
''';
  }

  // Real news/sports referrer pool with deep paths
  static String randomReferrer() {
    const refs = [
      'https://www.espncricinfo.com/series/icc-cricket-world-cup-2023-1357895',
      'https://www.espncricinfo.com/live-cricket-score',
      'https://www.cricbuzz.com/live-cricket-scores/12345',
      'https://www.cricbuzz.com/cricket-match/ind-vs-pak',
      'https://www.goal.com/en-in/match/premier-league',
      'https://www.goal.com/en-in/news/transfer-news',
      'https://www.hotstar.com/in/sports/cricket',
      'https://www.hotstar.com/in/sports/football',
      'https://www.sportskeeda.com/cricket',
      'https://www.sportskeeda.com/football',
      'https://www.google.com/search?q=live+cricket',
      'https://www.google.com/search?q=live+football',
      'https://m.facebook.com/',
      'https://t.co/',
      'https://www.bing.com/search?q=live+sports',
      'https://duckduckgo.com/?q=live+cricket+stream',
      '',
    ];
    return refs[_rng.nextInt(refs.length)];
  }

  // Per-zone click rate tracking (simple in-memory)
  static final Map<String, int> _zoneClickCounts = {};
  static final Map<String, DateTime> _zoneSkipUntil = {};

  static bool shouldSkipClickForZone(String zoneId) {
    final skipUntil = _zoneSkipUntil[zoneId];
    if (skipUntil != null && DateTime.now().isBefore(skipUntil)) {
      return true;
    }
    return false;
  }

  static void recordZoneClick(String zoneId) {
    _zoneClickCounts[zoneId] = (_zoneClickCounts[zoneId] ?? 0) + 1;
    // If click rate exceeds 6%, skip for 5 minutes
    if (_zoneClickCounts[zoneId]! > 6) {
      _zoneSkipUntil[zoneId] = DateTime.now().add(const Duration(minutes: 5));
      _zoneClickCounts[zoneId] = 0;
    }
  }

  static int jitterMs(int minMs, int maxMs) =>
      minMs + _rng.nextInt(maxMs - minMs + 1);

  static bool roll(double probability) => _rng.nextDouble() < probability;

  // Enhanced humanClickJs with curved path, pointer events, isTrusted shim, coordinate variation
  static String humanClickJs(int targetX, int targetY) {
    final startX = _rng.nextInt(80) + 10;
    final startY = _rng.nextInt(120) + 40;
    final dur = jitterMs(400, 1800);
    final offsetX = _rng.nextInt(16) - 8; // ±8px offset
    final offsetY = _rng.nextInt(16) - 8;
    final actualX = targetX + offsetX;
    final actualY = targetY + offsetY;
    final mouseDownDelay = jitterMs(60, 140);
    
    return '''
(function(){
  // isTrusted shim via createEvent path
  var createTrustedEvent = function(type, x, y) {
    var event = document.createEvent('MouseEvents');
    event.initMouseEvent(type, true, true, window, 0, x, y, x, y, false, false, false, false, 0, null);
    return event;
  };
  
  var dispatchTrusted = function(type, x, y) {
    var e = createTrustedEvent(type, x, y);
    var el = document.elementFromPoint(x, y);
    if (el) {
      el.dispatchEvent(e);
    }
  };
  
  // Pointer events for modern SDKs
  var dispatchPointer = function(type, x, y) {
    var e = new PointerEvent(type, {
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: y,
      isPrimary: true,
      pointerId: 1
    });
    var el = document.elementFromPoint(x, y);
    if (el) {
      el.dispatchEvent(e);
    }
  };
  
  // Curved path with 3-6 intermediate points
  var steps = 3 + Math.floor(Math.random() * 4);
  var i = 0;
  var iv = setInterval(function(){
    var t = i / steps;
    // Bezier curve
    var ease = t * t * (3 - 2 * t);
    var x = $startX + ($actualX - $startX) * ease;
    var y = $startY + ($actualY - $startY) * ease + (Math.random() * 4 - 2);
    
    dispatchTrusted('mousemove', x, y);
    dispatchPointer('pointermove', x, y);
    
    if (i === steps) {
      clearInterval(iv);
      
      // Pre-click delay (already handled in Dart, but add small JS delay)
      setTimeout(function() {
        dispatchTrusted('mousedown', $actualX, $actualY);
        dispatchPointer('pointerdown', $actualX, $actualY);
      }, $mouseDownDelay);
      
      setTimeout(function() {
        dispatchTrusted('mouseup', $actualX, $actualY);
        dispatchPointer('pointerup', $actualX, $actualY);
        dispatchTrusted('click', $actualX, $actualY);
      }, $mouseDownDelay + 80 + Math.random() * 60);
    }
    i++;
  }, ${dur ~/ 16});
})();
''';
  }

  // Poisson distribution for rotation intervals
  static int poissonNextRotationSeconds(int meanSeconds, int minS, int maxS) {
    // Box-Muller transform for normal approximation
    var u1 = _rng.nextDouble();
    var u2 = _rng.nextDouble();
    var z = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    var seconds = (meanSeconds + z * (meanSeconds / 3)).round();
    // Clamp to min/max
    if (seconds < minS) seconds = minS + _rng.nextInt(meanSeconds - minS);
    if (seconds > maxS) seconds = maxS - _rng.nextInt(maxS - meanSeconds);
    return seconds;
  }

  static int nextRotationSeconds(int minS, int maxS) {
    return poissonNextRotationSeconds(110, minS, maxS);
  }
}
