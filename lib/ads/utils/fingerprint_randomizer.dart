import 'dart:math';

class FingerprintRandomizer {
  FingerprintRandomizer._();
  static final _rng = Random.secure();

  // Realistic mobile UA pool — rotate per WebView instance.
  static const _uaPool = <String>[
    'Mozilla/5.0 (Linux; Android 13; SM-A536B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 12; RMX3686) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; M2102J20SG) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 14; CPH2451) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
  ];

  static String randomUserAgent() => _uaPool[_rng.nextInt(_uaPool.length)];

  static String randomReferrer() {
    const refs = [
      'https://www.google.com/',
      'https://m.facebook.com/',
      'https://t.co/',
      'https://www.bing.com/',
      'https://duckduckgo.com/',
      '',
    ];
    return refs[_rng.nextInt(refs.length)];
  }

  static int jitterMs(int minMs, int maxMs) =>
      minMs + _rng.nextInt(maxMs - minMs + 1);

  static int nextRotationSeconds(int minS, int maxS) =>
      minS + _rng.nextInt(maxS - minS + 1);

  static bool roll(double probability) => _rng.nextDouble() < probability;

  // Randomized viewport — mid-range mobile screens only.
  static (int, int) randomViewport() {
    const sizes = <(int, int)>[
      (360, 800),
      (393, 851),
      (412, 915),
      (375, 812),
      (390, 844),
    ];
    return sizes[_rng.nextInt(sizes.length)];
  }

  // Bezier-style mouse path generator for humanized clicks.
  static String humanClickJs(int targetX, int targetY) {
    final startX = _rng.nextInt(80) + 10;
    final startY = _rng.nextInt(120) + 40;
    final dur = jitterMs(380, 920);
    return '''
(function(){
  var ev = function(type,x,y){
    var e = new MouseEvent(type,{bubbles:true,cancelable:true,clientX:x,clientY:y,view:window});
    document.elementFromPoint(x,y)?.dispatchEvent(e);
  };
  var steps = 14 + Math.floor(Math.random()*8);
  var i = 0;
  var iv = setInterval(function(){
    var t = i/steps;
    var x = $startX + ($targetX - $startX) * (t*t*(3-2*t));
    var y = $startY + ($targetY - $startY) * (t*t*(3-2*t)) + (Math.random()*4-2);
    ev('mousemove', x, y);
    if(i===steps){
      clearInterval(iv);
      setTimeout(function(){ ev('mousedown',$targetX,$targetY); }, 40 + Math.random()*80);
      setTimeout(function(){ ev('mouseup',$targetX,$targetY); ev('click',$targetX,$targetY); }, 120 + Math.random()*120);
    }
    i++;
  }, ${dur ~/ 16});
})();
''';
  }
}
