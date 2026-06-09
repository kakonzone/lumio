import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;

/// Form mode for source input
enum SourceFormMode {
  onboarding,
  settings,
}

/// Shared source form widget
class SourceForm extends StatefulWidget {
  final SourceFormMode mode;
  final String? initialUrl;
  final String? initialName;
  final bool? isEditing;
  final void Function(String url, String? name) onSubmit;
  final VoidCallback? onCancel;

  const SourceForm({
    super.key,
    required this.mode,
    this.initialUrl,
    this.initialName,
    this.isEditing,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<SourceForm> createState() => _SourceFormState();
}

class _SourceFormState extends State<SourceForm> {
  late TextEditingController _urlController;
  late TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  bool _isValidating = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      setState(() => _isValidating = true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      final url = _urlController.text.trim();
      final name = _nameController.text.trim().isEmpty 
          ? null 
          : _nameController.text.trim();
      
      widget.onSubmit(url, name);
      
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _isLoading = false);
      HapticFeedback.heavyImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Strings.errorGeneric),
            backgroundColor: tokens.AppTokens.danger,
          ),
        );
      }
    }
  }

  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a playlist URL';
    }
    
    final url = value.trim();
    
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL Input
          Container(
            decoration: BoxDecoration(
              color: tokens.AppTokens.surface2,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(tokens.SpacingTokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mode == SourceFormMode.onboarding ? 'Add Source' : 'Source URL',
                  style: TextStyle(
                    color: tokens.AppTokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: tokens.SpacingTokens.s12),
                TextFormField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'https://example.com/playlist.m3u',
                    hintStyle: TextStyle(
                      color: tokens.AppTokens.textTertiary,
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: tokens.AppTokens.border,
                        width: 1,
                      ),
                    ),
                    errorText: _isValidating ? null : null,
                    filled: true,
                    fillColor: tokens.AppTokens.surface3,
                  ),
                  style: TextStyle(
                    color: tokens.AppTokens.textPrimary,
                    fontSize: 16,
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  validator: _validateUrl,
                  onFieldSubmitted: (_) {
                    if (widget.mode == SourceFormMode.settings) {
                      FocusScope.of(context).nextFocus();
                    } else {
                      _handleSubmit();
                    }
                  },
                ),
              ],
            ),
          ),
          
          SizedBox(height: tokens.SpacingTokens.s16),
          
          // Name Input (only in settings mode)
          if (widget.mode == SourceFormMode.settings) ...[
            Container(
              decoration: BoxDecoration(
                color: tokens.AppTokens.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.all(tokens.SpacingTokens.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Source Name (Optional)',
                    style: TextStyle(
                      color: tokens.AppTokens.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: tokens.SpacingTokens.s12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'My Playlist',
                      hintStyle: TextStyle(
                        color: tokens.AppTokens.textTertiary,
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: tokens.AppTokens.border,
                          width: 1,
                        ),
                      ),
                      filled: true,
                      fillColor: tokens.AppTokens.surface3,
                    ),
                    style: TextStyle(
                      color: tokens.AppTokens.textPrimary,
                      fontSize: 16,
                    ),
                    autocorrect: false,
                    enableSuggestions: false,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleSubmit(),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.SpacingTokens.s16),
          ],
          
          // Info section (onboarding only)
          if (widget.mode == SourceFormMode.onboarding) ...[
            Container(
              padding: EdgeInsets.all(tokens.SpacingTokens.s16),
              decoration: BoxDecoration(
                color: tokens.AppTokens.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tokens.AppTokens.border,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.info(),
                    color: tokens.AppTokens.textSecondary,
                    size: 20,
                  ),
                  SizedBox(width: tokens.SpacingTokens.s12),
                  Expanded(
                    child: Text(
                      'Paste an M3U playlist URL from your IPTV provider',
                      style: TextStyle(
                        color: tokens.AppTokens.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.SpacingTokens.s24),
          ],
          
          // Action buttons
          Row(
            children: [
              // Cancel button (settings only)
              if (widget.mode == SourceFormMode.settings) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.AppTokens.textPrimary,
                      side: BorderSide(
                        color: tokens.AppTokens.border,
                        width: 1,
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: tokens.SpacingTokens.s16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(width: tokens.SpacingTokens.s12),
              ],
              
              // Submit button
              Expanded(
                flex: widget.mode == SourceFormMode.settings ? 1 : 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.AppTokens.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: tokens.AppTokens.surface3,
                    padding: EdgeInsets.symmetric(
                      vertical: tokens.SpacingTokens.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.mode == SourceFormMode.onboarding
                              ? 'Next'
                              : (widget.isEditing == true ? 'Update Source' : 'Add Source'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          
          // Skip button (onboarding only)
          if (widget.mode == SourceFormMode.onboarding) ...[
            SizedBox(height: tokens.SpacingTokens.s16),
            Center(
              child: TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: tokens.AppTokens.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Simplified source form for onboarding
class OnboardingSourceForm extends StatelessWidget {
  final String? initialUrl;
  final void Function(String url, String? name) onSubmit;
  final VoidCallback onSkip;

  const OnboardingSourceForm({
    super.key,
    this.initialUrl,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SourceForm(
      mode: SourceFormMode.onboarding,
      initialUrl: initialUrl,
      onSubmit: onSubmit,
      onCancel: onSkip,
    );
  }
}

/// Full source form for settings
class SettingsSourceForm extends StatelessWidget {
  final String? initialUrl;
  final String? initialName;
  final bool isEditing;
  final void Function(String url, String? name) onSubmit;
  final VoidCallback onCancel;

  const SettingsSourceForm({
    super.key,
    this.initialUrl,
    this.initialName,
    required this.isEditing,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SourceForm(
      mode: SourceFormMode.settings,
      initialUrl: initialUrl,
      initialName: initialName,
      isEditing: isEditing,
      onSubmit: onSubmit,
      onCancel: onCancel,
    );
  }
}
