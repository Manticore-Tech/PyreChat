import 'package:flutter/material.dart';

/// Interactive swipe-right to pop — Snapchat-style chat dismiss.
class SwipeBackScope extends StatefulWidget {
  const SwipeBackScope({
    super.key,
    required this.child,
    this.edgeWidth = 56,
    this.commitSlop = 10,
  });

  final Widget child;
  final double edgeWidth;
  final double commitSlop;

  @override
  State<SwipeBackScope> createState() => _SwipeBackScopeState();
}

class _SwipeBackScopeState extends State<SwipeBackScope> with SingleTickerProviderStateMixin {
  double _drag = 0;
  bool _dragging = false;
  int? _activePointer;
  Offset? _down;
  double _lastX = 0;
  double _velocity = 0;
  Duration? _lastMoveAt;
  late final AnimationController _snapBack;

  @override
  void initState() {
    super.initState();
    _snapBack = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_snapBack.isAnimating) {
          setState(() => _drag = _snapBack.value);
        }
      });
  }

  @override
  void dispose() {
    _snapBack.dispose();
    super.dispose();
  }

  void _resetPointer() {
    _activePointer = null;
    _down = null;
    _velocity = 0;
    _lastMoveAt = null;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _down = event.position;
    _lastX = event.position.dx;
    _velocity = 0;
    _lastMoveAt = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _down == null) return;

    final delta = event.position.dx - _lastX;
    _lastX = event.position.dx;
    if (_lastMoveAt != null) {
      final dt = event.timeStamp - _lastMoveAt!;
      if (dt.inMicroseconds > 0) {
        _velocity = delta / dt.inMicroseconds * 1000000;
      }
    }
    _lastMoveAt = event.timeStamp;

    if (!_dragging) {
      final total = event.position - _down!;
      if (total.dx < widget.commitSlop) return;
      if (total.dy.abs() >= total.dx.abs()) {
        _resetPointer();
        return;
      }
      if (total.dx < 0) {
        _resetPointer();
        return;
      }
    }

    _onDragUpdate(delta);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _onDragEnd(_velocity);
    _resetPointer();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _onDragEnd(0);
    _resetPointer();
  }

  void _onDragUpdate(double delta) {
    if (delta <= 0 && _drag == 0) return;
    setState(() {
      _dragging = true;
      final width = MediaQuery.sizeOf(context).width;
      _drag = (_drag + delta).clamp(0, width);
    });
  }

  void _onDragEnd(double velocity) {
    if (!_dragging && _drag == 0) return;

    final width = MediaQuery.sizeOf(context).width;
    final shouldPop = _drag > width * 0.33 || velocity > 900;
    if (shouldPop) {
      Navigator.of(context).pop();
      return;
    }

    _snapBack
      ..value = _drag
      ..animateTo(0, curve: Curves.easeOutCubic).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _dragging = false;
          _drag = 0;
        });
      });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final progress = width <= 0 ? 0.0 : (_drag / width).clamp(0.0, 1.0);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Stack(
        children: [
          Transform.translate(
            offset: Offset(_drag, 0),
            child: IgnorePointer(
              ignoring: _drag > 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: progress > 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35 * progress),
                            blurRadius: 18,
                            offset: const Offset(-6, 0),
                          ),
                        ]
                      : const [],
                ),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide-in route for chat threads.
Route<T> chatThreadRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}
