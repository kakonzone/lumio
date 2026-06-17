// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/settings/settings_section.dart';
import 'package:lumio_tv/widgets/settings/settings_row.dart';
import 'package:lumio_tv/widgets/shell_app_bar.dart';
import 'package:lumio_tv/widgets/shell_page_scaffold.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Settings screen with sectioned organization.
///
/// Structure:
/// SECTION 1: Playback - Quality, Audio, Subtitles, Autoplay, Reduce motion
/// SECTION 2: Downloads - Quality, Wi-Fi only, Storage
/// SECTION 3: Display - Theme, App icon, Player background
/// SECTION 4: Parental - Profile lock, Content rating, Hide adult
/// SECTION 5: Privacy & Data - Personalized recs, Clear history, Diagnostic data
/// SECTION 6: About - Version, Licenses, Terms, Privacy, Contact support
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  bool _autoplayNext = true;
  bool _reduceMotion = false;
  bool _downloadWifi = true;
  String _theme = Strings.settingsThemeDark;
  bool _profileLock = false;
  final String _contentRating = 'TV-MA';
  bool _hideAdult = false;
  bool _personalizedRecs = true;
  bool _diagnosticData = false;

  // Mock data
  String _appVersion = 'Loading...';
  // final bool _isUpToDate = true; // Removed as unused

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShellPageScaffold(
      appBar: ShellAppBar(
        title: 'Settings',
        showBack: true,
      ),
      slivers: [
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: tokens.SpacingTokens.s24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: Playback
                SettingsSection(
                  title: Strings.settingsPlayback,
                  rows: [
                    SettingsRow(
                      leadingIcon: PhosphorIcons.monitor(),
                      title: Strings.settingsDefaultQuality,
                      value: Strings.settingsAuto,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show quality selector
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.speakerHigh(),
                      title: Strings.settingsAudioLanguage,
                      value: 'English',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show audio language selector
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.closedCaptioning(),
                      title: Strings.settingsSubtitleLanguage,
                      value: 'English',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show subtitle language selector
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.textT(),
                      title: Strings.settingsSubtitleAppearance,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Open subtitle preview screen
                      },
                    ),
                    SettingsRow.switchRow(
                      leadingIcon: PhosphorIcons.play(),
                      title: Strings.settingsAutoplayNext,
                      value: _autoplayNext,
                      onChanged: (value) {
                        setState(() {
                          _autoplayNext = value;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                    SettingsRow.switchRow(
                      leadingIcon: PhosphorIcons.waves(),
                      title: Strings.settingsReduceMotion,
                      value: _reduceMotion,
                      onChanged: (value) {
                        setState(() {
                          _reduceMotion = value;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),

                // SECTION 2: Downloads
                SettingsSection(
                  title: Strings.settingsDownloads,
                  rows: [
                    SettingsRow(
                      leadingIcon: PhosphorIcons.filmStrip(),
                      title: Strings.settingsDownloadQuality,
                      value: 'High (1080p)',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show download quality selector
                      },
                    ),
                    SettingsRow.switchRow(
                      leadingIcon: PhosphorIcons.wifiHigh(),
                      title: Strings.settingsDownloadWifi,
                      value: _downloadWifi,
                      onChanged: (value) {
                        setState(() {
                          _downloadWifi = value;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.hardDrive(),
                      title: Strings.settingsStorageUsed,
                      subtitle: '2.4 GB used',
                      value: 'Clear',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show storage clear dialog
                      },
                    ),
                  ],
                ),

                // SECTION 3: Display
                SettingsSection(
                  title: Strings.settingsDisplay,
                  rows: [
                    SettingsRow(
                      leadingIcon: PhosphorIcons.paintBrush(),
                      title: Strings.settingsTheme,
                      value: _theme,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showThemeSelector();
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.appWindow(),
                      title: Strings.settingsAppIcon,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show app icon selector (if supported)
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.drop(),
                      title: Strings.settingsPlayerBackground,
                      value: 'Black',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show player background tint selector
                      },
                    ),
                  ],
                ),

                // SECTION 4: Parental
                SettingsSection(
                  title: Strings.settingsParental,
                  rows: [
                    SettingsRow.switchRow(
                      leadingIcon: PhosphorIcons.lock(),
                      title: Strings.settingsProfileLock,
                      value: _profileLock,
                      onChanged: (value) {
                        setState(() {
                          _profileLock = value;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.shield(),
                      title: Strings.settingsContentRating,
                      value: _contentRating,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show content rating selector
                      },
                    ),
                    SettingsRow.switchRow(
                      leadingIcon: PhosphorIcons.eyeSlash(),
                      title: Strings.settingsHideAdult,
                      value: _hideAdult,
                      onChanged: (value) {
                        setState(() {
                          _hideAdult = value;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),

                // SECTION 5: Privacy & Data
                SettingsSection(
                  title: Strings.settingsPrivacy,
                  rows: [
                    SettingsRow.switchRow(
                      leadingIcon: PhosphorIcons.sparkle(),
                      title: Strings.settingsPersonalizedRecs,
                      value: _personalizedRecs,
                      onChanged: (value) {
                        setState(() {
                          _personalizedRecs = value;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.clockCounterClockwise(),
                      title: Strings.settingsClearWatchHistory,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showClearHistoryDialog(
                            Strings.settingsClearWatchHistory);
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.magnifyingGlassMinus(),
                      title: Strings.settingsClearSearchHistory,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showClearHistoryDialog(
                            Strings.settingsClearSearchHistory);
                      },
                    ),
                    SettingsRow.switchRow(
                      leadingIcon: PhosphorIcons.chartLineUp(),
                      title: Strings.settingsDiagnosticData,
                      subtitle: Strings.settingsShareDiagnostics,
                      value: _diagnosticData,
                      onChanged: (value) {
                        setState(() {
                          _diagnosticData = value;
                        });
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),

                // SECTION 6: About
                SettingsSection(
                  title: Strings.settingsAbout,
                  rows: [
                    SettingsRow(
                      leadingIcon: PhosphorIcons.info(),
                      title: Strings.settingsVersion,
                      value: _appVersion,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Check for updates
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.bookOpen(),
                      title: Strings.settingsOpenSourceLicenses,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Show open source licenses
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.fileText(),
                      title: Strings.settingsTerms,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Open terms
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.shieldCheck(),
                      title: Strings.settingsPrivacyPolicy,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Open privacy policy
                      },
                    ),
                    SettingsRow(
                      leadingIcon: PhosphorIcons.envelope(),
                      title: Strings.settingsContactSupport,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Open support contact
                      },
                    ),
                  ],
                ),

                // Bottom padding
                SizedBox(height: tokens.SpacingTokens.s32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface2,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.RadiusTokens.lg),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(tokens.SpacingTokens.s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Strings.settingsTheme,
                      style: tokens.TypographyTokens.titlePrimary,
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.x()),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Theme options
              _ThemeOption(
                label: Strings.settingsThemeDark,
                isSelected: _theme == Strings.settingsThemeDark,
                onTap: () {
                  setState(() {
                    _theme = Strings.settingsThemeDark;
                  });
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
              ),
              _ThemeOption(
                label: Strings.settingsThemeOled,
                isSelected: _theme == Strings.settingsThemeOled,
                onTap: () {
                  setState(() {
                    _theme = Strings.settingsThemeOled;
                  });
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
              ),
              _ThemeOption(
                label: Strings.settingsThemeSystem,
                isSelected: _theme == Strings.settingsThemeSystem,
                onTap: () {
                  setState(() {
                    _theme = Strings.settingsThemeSystem;
                  });
                  Navigator.pop(context);
                  HapticFeedback.selectionClick();
                },
              ),
              SizedBox(height: tokens.SpacingTokens.s16),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearHistoryDialog(String historyType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.AppTokens.surface2,
        title: Text(
          'Clear $historyType?',
          style: tokens.TypographyTokens.titlePrimary,
        ),
        content: Text(
          'This can\'t be undone.',
          style: tokens.TypographyTokens.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              Strings.notNow,
              style: tokens.TypographyTokens.labelPrimary,
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              // Clear history logic here
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.AppTokens.accent,
            ),
            child: Text(
              Strings.clear,
              style: tokens.TypographyTokens.labelPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Theme option widget for theme selector
class _ThemeOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.SpacingTokens.s16,
          vertical: tokens.SpacingTokens.s16,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: tokens.AppTokens.border,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: tokens.TypographyTokens.bodyPrimary,
            ),
            if (isSelected)
              Icon(
                PhosphorIcons.checkCircle(),
                size: 24,
                color: tokens.AppTokens.accent,
              ),
          ],
        ),
      ),
    );
  }
}
