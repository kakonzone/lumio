#!/usr/bin/env python3
"""Split player_screen.dart into lumio_player library (extensions, no transforms)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'lib/screens/player_screen.dart'
lines = SRC.read_text().splitlines()

shell_ranges = [(65, 116), (118, 224), (225, 280), (1768, 1802), (1886, 1952)]

failover_names = {
    '_canRunFailover', '_suppressFailoverFor', '_resetBufferingWatchdog',
    '_scheduleFailoverCheck', '_showFailoverExhaustedUi', '_retryCurrentLink',
    '_attemptFailover', '_trySchemeFlipForCurrentLink',
}
overlay_names = {
    '_onPlayerPaused', '_runPreRollThenPlay', '_presentMidRollInterstitial',
    '_dismissPlayerVideoAd', '_startMidRollTimer', '_buildPipOnlyUi',
    '_playerOverlayChip',
}
controls_names = {
    '_loadFitMode', '_persistFitMode', '_setFitMode', '_showFitModeSheet',
    '_buildVideoSurface', '_buildControls', '_buildProgressTimeRow',
    '_buildTopBar', '_buildLoadingSkeleton', '_buildSeekOverlay',
    '_buildChannelSwipeOverlay', '_buildStreamLinkStrip', '_buildDragIndicator',
    '_buildFullPlayerUi', '_buildPlayer', '_buildInfo', '_toggleControls',
    '_revealControls', '_startHideTimer', '_togglePlay', '_seek',
    '_toggleFullscreen', '_exitFullscreen', '_onDoubleTapDown',
    '_showSeekOverlay', '_onHorizontalDragEnd', '_onRetryPressed',
    '_onDragStart', '_onDragUpdate', '_onDragEnd', '_showQualityDialog',
    '_buildQualityDialog', '_applyQuality', '_updateQualityBadge',
    '_fitModeIcon', '_formatHeightLabel', '_safeUnitProgress',
    '_formatDuration', '_parsedQualityChoices', '_qualityIconFor',
    '_qualityOptionTile', '_selectableVideoTracks', '_trackHeight',
    '_heightMatchesTarget', '_findTrackForced', '_defaultChannelsForCategory',
}


def in_shell(ln1: int) -> bool:
    return any(a <= ln1 <= b for a, b in shell_ranges)


def parse_methods():
    methods = []
    i = 280
    while i < len(lines):
        ln = i + 1
        if in_shell(ln):
            i += 1
            continue
        line = lines[i]
        if not line.startswith('  ') or line.startswith('    '):
            i += 1
            continue
        if line.strip() == '@override':
            i += 1
            line = lines[i]
            if not line.startswith('  ') or line.startswith('    '):
                continue
        if re.match(r'^  static final ', line):
            while i < len(lines):
                if lines[i].strip().endswith('];'):
                    i += 1
                    break
                i += 1
            continue
        is_getter = ' get ' in line and '=>' not in line
        m = re.search(r'(?:get )?(_\w+)', line)
        if not m:
            i += 1
            continue
        name = m.group(1)
        start = i
        j = i
        brace_line = None
        while j < len(lines):
            cur = lines[j]
            if j > i and cur.startswith('  ') and not cur.startswith('    '):
                break
            if '{' in cur:
                brace_line = j
                break
            if cur.rstrip().endswith(';') and j == i:
                methods.append((name, start, i, is_getter))
                i += 1
                brace_line = None
                break
            j += 1
        if brace_line is None:
            i += 1
            continue
        depth = 0
        i = brace_line
        while i < len(lines):
            depth += lines[i].count('{') - lines[i].count('}')
            if depth <= 0 and lines[i].strip() == '}':
                methods.append((name, start, i, is_getter))
                break
            i += 1
        i += 1
    return methods


def categorize(name: str) -> str:
    if name in failover_names or 'failover' in name.lower():
        return 'failover'
    if name in overlay_names or 'MidRoll' in name or 'VideoAd' in name:
        return 'overlay'
    if name in controls_names or (
        name.startswith('_build') and name != '_buildPipOnlyUi'
    ):
        return 'controls'
    return 'state'


def main():
    methods = parse_methods()
    buckets = {k: [] for k in ('failover', 'overlay', 'controls', 'state')}
    for name, start, end, _ in methods:
        chunk = lines[start : end + 1]
        buckets[categorize(name)].extend(chunk)
        buckets['state'].append('')

    shell_parts = []
    for a, b in shell_ranges:
        shell_parts.extend(lines[a - 1 : b])
        shell_parts.append('')
    shell_parts.extend(lines[3356:3433])
    shell_parts.append('}')

    imports_text = (
        '\n'.join(lines[0:43])
        .replace("import '../", "import '../../")
        .replace(
            "import 'player_screen_widgets.dart'",
            "import '../player_screen_widgets.dart'",
        )
    )
    lib = f'''library lumio_player;

{imports_text}

part 'player_screen.dart';
part 'player_state_manager.dart';
part 'player_failover.dart';
part 'player_controls_bar.dart';
part 'player_overlay.dart';

{chr(10).join(lines[44:63])}
'''

    out_dir = ROOT / 'lib/screens/player'
    out_dir.mkdir(exist_ok=True)
    (out_dir / 'lumio_player.dart').write_text(lib)
    (out_dir / 'player_screen.dart').write_text(
        'part of lumio_player;\n\n' + '\n'.join(shell_parts) + '\n'
    )
    for cat, fname, comment in [
        ('state', 'player_state_manager.dart', 'State + lifecycle helpers'),
        ('failover', 'player_failover.dart', 'Retry + backup URL logic'),
        ('controls', 'player_controls_bar.dart', 'Controls UI'),
        ('overlay', 'player_overlay.dart', 'Ad overlays + mid-roll'),
    ]:
        body = buckets[cat]
        (out_dir / fname).write_text(
            f'part of lumio_player;\n\n// {comment}\n\n'
            f'extension _Player{cat.title().replace("_", "")} on _PlayerScreenState {{\n'
            + '\n'.join(body)
            + '\n}\n'
        )
    (ROOT / 'lib/screens/player_screen.dart').write_text(
        "export 'player/lumio_player.dart' show PlayerScreen;\n"
    )
    print(f'Split {len(methods)} methods (extension copy) -> {out_dir}')


if __name__ == '__main__':
    main()
