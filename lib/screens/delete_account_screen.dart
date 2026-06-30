// lib/screens/delete_account_screen.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/theme.dart';
import '../utils/web_theme.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _passCtrl = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  late final String _providerId;
  late final bool   _isGoogle;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _providerId = user?.providerData.isNotEmpty == true
        ? user!.providerData.first.providerId
        : 'password';
    _isGoogle = _providerId == 'google.com';
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    setState(() { _loading = true; _error = null; });

    try {
      await AuthService.deleteAccount(
        password: _isGoogle ? null : _passCtrl.text.trim(),
      );
      // Auth state change propagates back to main.dart's StreamBuilder,
      // which returns to the login/landing screen automatically.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'wrong-password'   => 'Incorrect password. Please try again.',
          'too-many-requests'=> 'Too many attempts. Please wait a moment.',
          'user-mismatch'    => 'Google account does not match. Try again.',
          _                  => 'Authentication failed: ${e.message}',
        };
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return kIsWeb ? _buildWeb(context) : _buildMobile(context);
  }

  // ── Mobile ───────────────────────────────────────────────────────────────────
  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
      ),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.loss, size: 40),
              const SizedBox(height: 16),
              const Text('Delete your account?',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'This action is permanent and cannot be undone.',
                style: TextStyle(color: AppTheme.loss, fontSize: 14),
              ),
              const SizedBox(height: 24),
              const _DeletionList(mobile: true),
              const SizedBox(height: 28),
              if (!_isGoogle) ...[
                const Text('Enter your password to confirm',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle:
                        const TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppTheme.textSecondary,
                          size: 18),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppTheme.textSecondary, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You\'ll be asked to re-confirm with your Google account before deletion.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (_error != null) ...[
                Text(_error!,
                    style: const TextStyle(
                        color: AppTheme.loss, fontSize: 13)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _deleteAccount,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.loss,
                    disabledBackgroundColor:
                        AppTheme.loss.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          _isGoogle
                              ? 'Confirm with Google & Delete'
                              : 'Delete my account',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Web ──────────────────────────────────────────────────────────────────────
  Widget _buildWeb(BuildContext context) {
    return Scaffold(
      backgroundColor: WT.scaffoldBg,
      appBar: webAppBar(context, title: 'Delete Account'),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WebSectionLabel('Danger Zone'),
                const SizedBox(height: 20),
                Text('Delete your account',
                    style: WT.anton(36,
                        color: WT.isDark ? WT.darkText : WT.ink,
                        spacing: 1.0)),
                const SizedBox(height: 8),
                Text(
                  'This is permanent and cannot be undone.',
                  style: WT.lora(14, color: WT.loss),
                ),
                const SizedBox(height: 32),
                const _DeletionList(mobile: false),
                const SizedBox(height: 32),
                Container(
                  height: 1,
                  color: WT.borderColor,
                ),
                const SizedBox(height: 28),
                if (!_isGoogle) ...[
                  Text('Enter your password to confirm',
                      style: WT.labelSm(13)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: TextStyle(
                        color: WT.textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: WT.mutedColor),
                      filled: true,
                      fillColor: WT.cardBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: WT.borderColor)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: WT.borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide:
                              BorderSide(color: WT.blunderColor, width: 1.5)),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: WT.mutedColor,
                            size: 18),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: WT.cardBg,
                      border: Border.all(color: WT.borderColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: WT.mutedColor, size: 16),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You\'ll be asked to re-confirm with your Google account before deletion proceeds.',
                            style: WT.lora(13, color: WT.mutedColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (_error != null) ...[
                  Text(_error!, style: WT.lora(13, color: WT.blunderColor)),
                  const SizedBox(height: 14),
                ],
                Row(
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : _deleteAccount,
                      style: FilledButton.styleFrom(
                        backgroundColor: WT.blunderColor,
                        disabledBackgroundColor:
                            WT.blunderColor.withValues(alpha: 0.4),
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(4))),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isGoogle
                                  ? 'Confirm with Google & Delete'
                                  : 'Permanently delete my account',
                              style: WT.lora(13,
                                  color: WT.white,
                                  weight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: WT.lora(13, color: WT.mutedColor,
                              weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── What gets deleted list ────────────────────────────────────────────────────
class _DeletionList extends StatelessWidget {
  final bool mobile;
  const _DeletionList({required this.mobile});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('All games in your library', true),
      ('Move sequences, analysis results, and coaching tips', true),
      ('Your account profile and email address', true),
      ('Linked Chess.com / Lichess account connections', true),
      ('Your sign-in credentials', true),
    ];
    final retained = [
      'Anonymised crash-report data retained by Firebase for up to 90 days',
    ];

    if (mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What will be deleted:',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 10),
          ...items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✕ ',
                        style: TextStyle(
                            color: AppTheme.loss, fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(e.$1,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13,
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          const Text('What may be retained:',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          const SizedBox(height: 8),
          ...retained.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $e',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12,
                        height: 1.4)),
              )),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What gets deleted immediately:',
            style: WT.labelSm(12)),
        const SizedBox(height: 10),
        ...items.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✕  ',
                      style: WT.lora(13, color: WT.blunderColor,
                          weight: FontWeight.w700)),
                  Expanded(
                      child: Text(e.$1, style: WT.lora(13))),
                ],
              ),
            )),
        const SizedBox(height: 18),
        Text('What may be retained:',
            style: WT.labelSm(12)),
        const SizedBox(height: 8),
        ...retained.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $e',
                  style: WT.bodySm(12)),
            )),
      ],
    );
  }
}
