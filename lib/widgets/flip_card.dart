import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A declarative 3D flip card.
///
/// The parent owns the `flipped` state (so keyboard shortcuts, buttons and
/// taps all go through one place); this widget just animates to it.
///
///   FlipCard(
///     flipped: _flipped,
///     onTap: () => setState(() => _flipped = !_flipped),
///     front: ...,
///     back: ...,
///   )
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.flipped,
    required this.front,
    required this.back,
    this.onTap,
    this.duration = const Duration(milliseconds: 480),
    this.curve = Curves.easeInOutCubic,
  });

  final bool flipped;
  final Widget front;
  final Widget back;
  final VoidCallback? onTap;
  final Duration duration;
  final Curve curve;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.flipped ? 1 : 0,
  );
  late final Animation<double> _animation =
      CurvedAnimation(parent: _controller, curve: widget.curve);

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flipped != oldWidget.flipped) {
      widget.flipped ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final angle = _animation.value * math.pi; // 0 -> π
            final showBack = angle > math.pi / 2;

            // Perspective + Y rotation.
            final transform = Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle);

            // Slight "lift" in the middle of the flip.
            final scale = 1 - 0.05 * math.sin(angle);

            final face = showBack
                // Counter-rotate the back so its text isn't mirrored.
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: widget.back,
                  )
                : widget.front;

            return Transform.scale(
              scale: scale,
              child: Transform(
                alignment: Alignment.center,
                transform: transform,
                child: face,
              ),
            );
          },
        ),
      ),
    );
  }
}
