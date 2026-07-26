import 'package:flutter/material.dart';
import '../../utils/biometric_auth.dart';

/// Hides [child] behind a tap-to-unlock biometric/PIN prompt. Used to guard
/// the delivery OTP from casual disclosure on an unlocked phone, without
/// requiring authentication just to view the surrounding order/screen.
class BiometricReveal extends StatefulWidget {
  final Widget child;
  final String reason;

  const BiometricReveal({super.key, required this.child, required this.reason});

  @override
  State<BiometricReveal> createState() => _BiometricRevealState();
}

class _BiometricRevealState extends State<BiometricReveal> {
  bool _revealed = false;
  bool _authenticating = false;

  Future<void> _unlock() async {
    if (_authenticating || _revealed) return;
    setState(() => _authenticating = true);
    final ok = await requestLocalAuth(widget.reason);
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (ok) _revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_revealed) return widget.child;

    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: _unlock,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _authenticating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: scheme.primary),
                  )
                : Icon(Icons.fingerprint_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 6),
            Text(
              _authenticating ? 'Verifying…' : 'Tap to reveal OTP',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
