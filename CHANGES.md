# CHANGES.md

## Player screen (previous pass)

See git history for player controls, PiP, quality tiers, slider clamp, and channel-switch performance.

---

## UI overflow + responsive layout (all screens)

### New: `lib/utils/responsive.dart`

- `Responsive.w` / `h` / `sp` — percent-based sizing from screen dimensions
- `Responsive.shellSideSlot` — narrower side gutters on small phones
- `OverflowSafeText` — ellipsis + optional `FittedBox` scale-down

### Navigation shell (`lib/main.dart`)

- Bottom nav: `LayoutBuilder` + compact padding when width &lt; 360px
- Nav labels already use `FittedBox`
- Drawer list titles: `maxLines` + ellipsis

### Shared widgets

- **`shell_app_bar.dart`**: dynamic side slots, `FittedBox` on right actions, `OverflowSafeText` for titles/subtitles
- **`section_nav_bar.dart`**: `SectionScreenHeader` leading icons → `Wrap` (no horizontal overflow)
- **`channel_list_tile.dart`**: subtitle `maxLines: 1`

### Home / Live tabs (`tv_screen.dart`)

- `_SectionHeader`: `Flexible` trailing, title `maxLines`
- `_LiveBadge`, `_LiveEventTeamRow` score: ellipsis / `FittedBox`
- `_TodayCard`: right column wrapped in `Flexible`
- `_UpcomingCard`: sport chip ellipsis
- Live events helper copy: `maxLines: 2`

### Sports / Live / News / Categories (`other_screens.dart`)

- Sports grid: live count ellipsis
- `_ChannelCard`: status column `Flexible`, viewers ellipsis
- Categories banner: title/subtitle ellipsis, count `FittedBox`
- `_GenreBadge`, `_WideGenreCard`: text overflow guards
- Predictions: team row `Expanded`, `_teamPill` ellipsis
- News cards: title (3 lines) + meta ellipsis
- Section headers: `Expanded` on titles

### Other screens

- **`favorites_screen.dart`**: empty-state hint `maxLines: 3`
- **`splash_screen.dart`**: logo width via `Responsive.w`
- **`category_channels_screen.dart`**: uses `ChannelListTile` (already safe)

### Patterns applied app-wide

| Issue | Fix |
|--------|-----|
| Long text in `Row` | `Expanded` / `Flexible` + `TextOverflow.ellipsis` |
| Fixed widths on small screens | `MediaQuery` / `Responsive` / `LayoutBuilder` |
| Chip/icon rows | `Wrap` or horizontal `ListView` |
| 1px overflow | `mainAxisSize: min`, `Flexible(loose)`, `FittedBox` |
| Scaffold top inset | `SafeArea` in `ShellAppBar` + bottom nav |

### Analyze

Run: `dart analyze lib/screens lib/widgets lib/main.dart lib/utils/responsive.dart`

### Commit message

```
fix(ui): resolve overflow issues + responsive layout across all screens
```
