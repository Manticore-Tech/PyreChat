import 'dart:ui';

/// One-Euro filter for low-latency smoothing of noisy tracking (per-axis).
class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = 1.2,
    this.beta = 0.08,
    this.dCutoff = 1.0,
  });

  final double minCutoff;
  final double beta;
  final double dCutoff;

  double? _lastValue;
  double? _lastDeriv;
  int? _lastTimeUs;

  double filter(double value, int timeUs) {
    if (_lastValue == null || _lastTimeUs == null) {
      _lastValue = value;
      _lastDeriv = 0;
      _lastTimeUs = timeUs;
      return value;
    }

    final dt = ((timeUs - _lastTimeUs!) / 1e6).clamp(1 / 120, 0.5);
    final deriv = (value - _lastValue!) / dt;
    final ed = _alpha(dt, dCutoff);
    final dHat = ed * deriv + (1 - ed) * (_lastDeriv ?? deriv);

    final cutoff = minCutoff + beta * dHat.abs();
    final a = _alpha(dt, cutoff);
    final vHat = a * value + (1 - a) * _lastValue!;

    _lastValue = vHat;
    _lastDeriv = dHat;
    _lastTimeUs = timeUs;
    return vHat;
  }

  void reset() {
    _lastValue = null;
    _lastDeriv = null;
    _lastTimeUs = null;
  }

  static double _alpha(double dt, double cutoff) {
    final tau = 1 / (2 * 3.141592653589793 * cutoff);
    return 1 / (1 + tau / dt);
  }
}

class MeshSmoother {
  MeshSmoother(int count)
      : _fx = List.generate(count, (_) => OneEuroFilter()),
        _fy = List.generate(count, (_) => OneEuroFilter());

  final List<OneEuroFilter> _fx;
  final List<OneEuroFilter> _fy;

  List<Offset> smooth(List<Offset> next, int timeUs) {
    if (next.length != _fx.length) {
      for (final f in _fx) {
        f.reset();
      }
      for (final f in _fy) {
        f.reset();
      }
      return next;
    }
    return List.generate(
      next.length,
      (i) => Offset(
        _fx[i].filter(next[i].dx, timeUs),
        _fy[i].filter(next[i].dy, timeUs),
      ),
    );
  }

  void reset() {
    for (final f in _fx) {
      f.reset();
    }
    for (final f in _fy) {
      f.reset();
    }
  }
}
