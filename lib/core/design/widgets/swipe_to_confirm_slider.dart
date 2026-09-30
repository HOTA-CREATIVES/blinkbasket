import 'package:flutter/material.dart';

class SwipeToConfirmSlider extends StatefulWidget {
  final String text;
  final Color color;
  final VoidCallback onSwipeCompleted;

  /// When false the slider ignores drags and looks dimmed. Callers turn it off
  /// while the action it triggers is still running, so a second swipe can't
  /// start a duplicate request.
  final bool enabled;

  const SwipeToConfirmSlider({
    super.key,
    required this.text,
    required this.color,
    required this.onSwipeCompleted,
    this.enabled = true,
  });

  @override
  State<SwipeToConfirmSlider> createState() => _SwipeToConfirmSliderState();
}

class _SwipeToConfirmSliderState extends State<SwipeToConfirmSlider>
    with SingleTickerProviderStateMixin {
  double _dragProgress = 0.0; // 0.0 to 1.0
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _resetAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxDistance) {
    if (!widget.enabled || _resetController.isAnimating) return;
    setState(() {
      _dragProgress += details.delta.dx / maxDistance;
      _dragProgress = _dragProgress.clamp(0.0, 1.0);
    });
  }

  void _onDragEnd() {
    if (_resetController.isAnimating) return;
    if (!widget.enabled) {
      if (_dragProgress != 0) setState(() => _dragProgress = 0);
      return;
    }
    if (_dragProgress >= 0.9) {
      // Trigger callback
      widget.onSwipeCompleted();
      // Keep it at 1.0 briefly or reset
      setState(() {
        _dragProgress = 1.0;
      });
      // Delay resetting to give visual feedback
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _dragProgress = 0.0;
          });
        }
      });
    } else {
      // Reset with animation
      _resetAnimation = Tween<double>(begin: _dragProgress, end: 0.0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
      )..addListener(() {
        setState(() {
          _dragProgress = _resetAnimation.value;
        });
      });
      _resetController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double height = 56.0;
        const double buttonSize = 48.0;
        final double maxDistance = width - buttonSize - 8.0; // padding around

        // setState fires on every drag delta (~60fps while dragging) — this
        // isolates that repaint to the slider itself, not whatever it sits
        // in (a bottomSheet, here).
        return Semantics(
          button: true,
          enabled: widget.enabled,
          label: widget.text,
          // A swipe is not possible with a screen reader, so expose the action
          // as a plain activation.
          onTap: widget.enabled ? widget.onSwipeCompleted : null,
          child: ExcludeSemantics(
            child: Opacity(
              opacity: widget.enabled ? 1.0 : 0.5,
              child: RepaintBoundary(
                child: Container(
                  width: width,
                  height: height,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(height / 2),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Center Label Text
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 50.0),
                          child: ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [
                                  widget.color.withValues(alpha: 0.6),
                                  widget.color,
                                  widget.color.withValues(alpha: 0.6),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ).createShader(bounds);
                            },
                            child: Text(
                              widget.text,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Draggable Thumb
                      Positioned(
                        left: 4.0 + (_dragProgress * maxDistance),
                        child: GestureDetector(
                          onHorizontalDragUpdate:
                              (details) => _onDragUpdate(details, maxDistance),
                          onHorizontalDragEnd: (_) => _onDragEnd(),
                          child: Container(
                            width: buttonSize,
                            height: buttonSize,
                            decoration: BoxDecoration(
                              color: widget.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.color.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.double_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
