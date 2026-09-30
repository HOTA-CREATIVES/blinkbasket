import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../app_tokens.dart';

/// Shown to email/password customers until they verify their address: the
/// server refuses orders from unverified accounts, so this tells them why and
/// how to fix it. Renders nothing once verified.
class EmailVerificationBanner extends StatelessWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isEmailVerified) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final email = auth.currentUserModel?.email ?? '';
    final busy = auth.isSendingVerification || auth.isCheckingVerification;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        color: AppTokens.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        border: Border.all(color: AppTokens.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.mark_email_unread_outlined,
                  color: AppTokens.warning, size: 20),
              const SizedBox(width: AppTokens.s8),
              Expanded(
                child: Text(
                  email.isEmpty
                      ? 'Verify your email to place orders.'
                      : 'Verify your email to place orders. We sent a link to $email.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Wrap(
            spacing: AppTokens.s8,
            children: [
              TextButton(
                onPressed: busy ? null : () => _resend(context),
                child: const Text('Resend link'),
              ),
              FilledButton.tonal(
                onPressed: busy ? null : () => _check(context),
                child: auth.isCheckingVerification
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("I've verified"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resend(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AuthProvider>().resendVerificationEmail();
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Verification email sent. Check your inbox.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _check(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final verified = await context.read<AuthProvider>().refreshEmailVerified();
    if (verified) return; // The banner disappears on its own.
    messenger.showSnackBar(const SnackBar(
      content: Text("Your email isn't verified yet. Open the link we emailed you, then try again."),
      behavior: SnackBarBehavior.floating,
    ));
  }
}
