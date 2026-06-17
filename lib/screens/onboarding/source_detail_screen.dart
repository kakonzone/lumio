// lib/screens/onboarding/source_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lumio_tv/l10n/strings.dart';
import 'package:lumio_tv/screens/onboarding/onboarding_controller.dart';
import 'package:lumio_tv/theme/tokens/colors.dart' as tokens;
import 'package:lumio_tv/theme/tokens/radius.dart' as tokens;
import 'package:lumio_tv/theme/tokens/spacing.dart' as tokens;
import 'package:lumio_tv/theme/tokens/typography.dart' as tokens;
import 'package:lumio_tv/widgets/common/pressable.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Source detail screen - Screen 3 of onboarding
///
/// Features:
/// - Form for selected method with proper validation
/// - Submit triggers loading state with skeleton
/// - Success → animated checkmark + transition to next screen
/// - Error → inline error message, accent retry button
class SourceDetailScreen extends StatefulWidget {
  final OnboardingSourceType sourceType;
  final VoidCallback onSuccess;
  final VoidCallback onBack;

  const SourceDetailScreen({
    super.key,
    required this.sourceType,
    required this.onSuccess,
    required this.onBack,
  });

  @override
  State<SourceDetailScreen> createState() => _SourceDetailScreenState();
}

class _SourceDetailScreenState extends State<SourceDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();

  bool _isLoading = false;
  bool _showSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.sourceType) {
      case OnboardingSourceType.m3u:
        return Strings.onboardingSourceM3UTitle;
      case OnboardingSourceType.xtream:
        return Strings.onboardingSourceXtreamTitle;
      case OnboardingSourceType.upload:
        return Strings.onboardingSourceUpload;
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Simulate success (in real app, validate the source)
    setState(() {
      _isLoading = false;
      _showSuccess = true;
    });

    HapticFeedback.mediumImpact();

    // Auto-advance after success animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onSuccess();
      }
    });
  }

  void _handleRetry() {
    setState(() {
      _errorMessage = null;
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: tokens.AppTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Pressable(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onBack();
          },
          child: Icon(
            PhosphorIcons.caretLeft(),
            color: tokens.AppTokens.textPrimary,
          ),
        ),
        title: Text(
          _title,
          style: tokens.TypographyTokens.titlePrimary,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.SpacingTokens.s24,
            vertical: tokens.SpacingTokens.s16,
          ),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_showSuccess) {
      return _buildSuccessState();
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_isLoading) ...[
            _buildLoadingState(),
          ] else ...[
            _buildForm(),
            if (_errorMessage != null) ...[
              SizedBox(height: tokens.SpacingTokens.s16),
              _buildErrorState(),
            ],
            SizedBox(height: tokens.SpacingTokens.s32),
            _buildSubmitButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    switch (widget.sourceType) {
      case OnboardingSourceType.m3u:
        return _buildM3UForm();
      case OnboardingSourceType.xtream:
        return _buildXtreamForm();
      case OnboardingSourceType.upload:
        return _buildUploadForm();
    }
  }

  Widget _buildM3UForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Strings.onboardingSourceUrlLabel,
          style: tokens.TypographyTokens.labelPrimary,
        ),
        SizedBox(height: tokens.SpacingTokens.s8),
        TextFormField(
          controller: _urlController,
          decoration: InputDecoration(
            hintText: Strings.onboardingSourceUrlPlaceholder,
            filled: true,
            fillColor: tokens.AppTokens.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s16,
              vertical: tokens.SpacingTokens.s12,
            ),
          ),
          style: tokens.TypographyTokens.bodyPrimary,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return Strings.fieldRequired;
            }
            // Basic URL validation
            if (!value.startsWith('http')) {
              return Strings.invalidUrl;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildXtreamForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Strings.onboardingSourceServerUrlLabel,
          style: tokens.TypographyTokens.labelPrimary,
        ),
        SizedBox(height: tokens.SpacingTokens.s8),
        TextFormField(
          controller: _serverUrlController,
          decoration: InputDecoration(
            hintText: 'http://your-server.com',
            filled: true,
            fillColor: tokens.AppTokens.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s16,
              vertical: tokens.SpacingTokens.s12,
            ),
          ),
          style: tokens.TypographyTokens.bodyPrimary,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return Strings.fieldRequired;
            }
            return null;
          },
        ),
        SizedBox(height: tokens.SpacingTokens.s16),
        Text(
          Strings.onboardingSourceUsernameLabel,
          style: tokens.TypographyTokens.labelPrimary,
        ),
        SizedBox(height: tokens.SpacingTokens.s8),
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: 'Username',
            filled: true,
            fillColor: tokens.AppTokens.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s16,
              vertical: tokens.SpacingTokens.s12,
            ),
          ),
          style: tokens.TypographyTokens.bodyPrimary,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return Strings.fieldRequired;
            }
            return null;
          },
        ),
        SizedBox(height: tokens.SpacingTokens.s16),
        Text(
          Strings.onboardingSourcePasswordLabel,
          style: tokens.TypographyTokens.labelPrimary,
        ),
        SizedBox(height: tokens.SpacingTokens.s8),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Password',
            filled: true,
            fillColor: tokens.AppTokens.surface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: tokens.SpacingTokens.s16,
              vertical: tokens.SpacingTokens.s12,
            ),
          ),
          style: tokens.TypographyTokens.bodyPrimary,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return Strings.fieldRequired;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUploadForm() {
    return Pressable(
      onTap: () {
        // ISSUE: Implement file picker
        // See: https://github.com/your-repo/issues/XXX
        HapticFeedback.lightImpact();
      },
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: tokens.AppTokens.surface2,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
          border: Border.all(
            color: tokens.AppTokens.border,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.uploadSimple(),
              size: 48,
              color: tokens.AppTokens.accent,
            ),
            SizedBox(height: tokens.SpacingTokens.s16),
            Text(
              'Tap to select M3U file',
              style: tokens.TypographyTokens.bodyPrimary,
            ),
            SizedBox(height: tokens.SpacingTokens.s8),
            Text(
              'Supports .m3u and .m3u8 files',
              style: tokens.TypographyTokens.captionSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: tokens.AppTokens.accent,
          ),
          SizedBox(height: tokens.SpacingTokens.s16),
          Text(
            Strings.onboardingSourceValidating,
            style: tokens.TypographyTokens.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: tokens.AppTokens.success,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              PhosphorIcons.check(),
              size: 48,
              color: Colors.white,
            ),
          ),
          SizedBox(height: tokens.SpacingTokens.s24),
          Text(
            Strings.onboardingSourceSuccess,
            style: tokens.TypographyTokens.titlePrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: EdgeInsets.all(tokens.SpacingTokens.s16),
      decoration: BoxDecoration(
        color: tokens.AppTokens.surface2,
        borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
        border: Border.all(
          color: tokens.AppTokens.danger,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIcons.warning(),
            color: tokens.AppTokens.danger,
            size: 20,
          ),
          SizedBox(width: tokens.SpacingTokens.s12),
          Expanded(
            child: Text(
              _errorMessage ?? Strings.onboardingSourceError,
              style: tokens.TypographyTokens.bodySecondary,
            ),
          ),
          Pressable(
            onTap: _handleRetry,
            child: Text(
              Strings.onboardingSourceRetry,
              style: tokens.TypographyTokens.labelAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Pressable(
      onTap: _handleSubmit,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          vertical: tokens.SpacingTokens.s16,
        ),
        decoration: BoxDecoration(
          color: tokens.AppTokens.accent,
          borderRadius: BorderRadius.circular(tokens.RadiusTokens.md),
        ),
        child: Text(
          Strings.onboardingSourceSubmit,
          style: tokens.TypographyTokens.labelPrimary,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
