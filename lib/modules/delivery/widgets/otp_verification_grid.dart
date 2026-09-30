import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/design/app_tokens.dart';
import '../../../core/providers/order_provider.dart';

class OtpVerificationGrid extends StatefulWidget {
  final String orderId;
  final VoidCallback onSuccess;

  const OtpVerificationGrid({
    super.key,
    required this.orderId,
    required this.onSuccess,
  });

  @override
  State<OtpVerificationGrid> createState() => _OtpVerificationGridState();
}

class _OtpVerificationGridState extends State<OtpVerificationGrid>
    with SingleTickerProviderStateMixin {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;
  bool _isVerifying = false;
  String? _serverError;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (_) => TextEditingController());
    _focusNodes = List.generate(4, (_) => FocusNode());

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 24.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var ctrl in _controllers) {
      ctrl.dispose();
    }
    for (var fn in _focusNodes) {
      fn.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    // Auto-submit on the 4th digit plus the button (or a re-edit of the last
    // box) can fire twice; each wrong call burns a server-side attempt.
    if (_isVerifying) return;
    final otp = _controllers.map((c) => c.text.trim()).join();
    if (otp.length != 4) {
      setState(() {
        _serverError = 'Please enter all 4 digits';
      });
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _isVerifying = true;
      _serverError = null;
    });

    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final error = await orderProvider.verifyDelivery(widget.orderId, otp);

      if (!mounted) return;

      if (error != null) {
        HapticFeedback.mediumImpact();
        _shakeController.forward(from: 0);
        setState(() {
          _isVerifying = false;
          _serverError = error;
          for (var ctrl in _controllers) {
            ctrl.clear();
          }
          _focusNodes[0].requestFocus();
        });
      } else {
        widget.onSuccess();
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
      setState(() {
        _isVerifying = false;
        _serverError = 'Verification failed. Please try again.';
        for (var ctrl in _controllers) {
          ctrl.clear();
        }
        _focusNodes[0].requestFocus();
      });
    }
  }

  void _onDigitInput(int index, String val) {
    if (_serverError != null) {
      setState(() {
        _serverError = null;
      });
    }
    if (val.isNotEmpty) {
      // Inputted a digit, move focus next
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered, trigger auto-submit
        _verifyOtp();
      }
    }
  }

  void _onDigitDelete(int index, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.rXl),
      ),
      title: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: scheme.primary),
          const SizedBox(width: 8),
          Text('Verify Delivery', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ask the customer for the 4-digit verification code shown in their app.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final double dx = _shakeAnimation.value;
              // Simple shake offset calculation
              final double offset = dx == 0
                  ? 0
                  : (dx * (1.0 - (dx / 24.0).clamp(0.0, 1.0)) * 
                      ((dx * 4).floor() % 2 == 0 ? 1 : -1));
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return SizedBox(
                  width: 56,
                  height: 56,
                  child: KeyboardListener(
                    focusNode: FocusNode(skipTraversal: true), // dedicated listener node
                    onKeyEvent: (event) => _onDigitDelete(index, event),
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _serverError != null ? scheme.error : scheme.onSurface,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          borderSide: BorderSide(
                            color: _serverError != null
                                ? scheme.error.withValues(alpha: 0.5)
                                : scheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTokens.rMd),
                          borderSide: BorderSide(
                            color: _serverError != null ? scheme.error : scheme.primary,
                            width: 2.0,
                          ),
                        ),
                      ),
                      onChanged: (val) => _onDigitInput(index, val),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (_serverError != null) ...[
            const SizedBox(height: 16),
            Text(
              _serverError!,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.rSm)),
          ),
          child: _isVerifying
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: scheme.onPrimary, strokeWidth: 2),
                )
              : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
