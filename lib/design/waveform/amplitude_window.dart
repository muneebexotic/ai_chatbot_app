import 'package:flutter/foundation.dart';

/// The rolling amplitude buffer behind the Waveform (PRD R7.5.1, R11.2).
///
/// ## Why this is a Listenable and not a widget field
///
/// R11.2: "The waveform MUST repaint via a `CustomPainter` driven by a single
/// ticker, never by rebuilding widgets per frame."
///
/// Passing amplitudes as a constructor argument to the `Waveform` widget makes
/// every new microphone sample a `setState` — a widget rebuild, a new painter
/// object, and an element tree walk, sixty times a second, for a change that
/// affects nothing but pixels inside one `CustomPaint`. That is precisely the
/// shape R11.2 rules out.
///
/// A `CustomPainter` constructed with `repaint:` a `Listenable` repaints when
/// that listenable notifies **without rebuilding anything**. So the live
/// amplitude lives here, the painter reads it at paint time, and the widget's
/// `build` runs once per configuration change rather than once per frame.
///
/// ## Why a ring buffer
///
/// At 60fps a `List.removeAt(0)` plus an `add` is two O(n) operations and a
/// fresh allocation every frame, for the whole length of a twenty-minute
/// session. R11.3 caps memory at 250MB and R11.4 caps battery; neither survives
/// gratuitous per-frame garbage. Writes here are one array store and one
/// integer increment.
///
/// ## Why the samples are smoothed
///
/// `speech_to_text` reports sound level roughly ten to twenty times a second,
/// not sixty. Drawing those raw would produce visible steps — the waveform
/// would tick rather than flow, which reads as a dropped frame rather than as a
/// quiet moment. [advance] runs once per ticker frame and eases the newest bar
/// toward the most recent real reading, so the motion is continuous at 60fps
/// while every value still comes from the microphone.
class AmplitudeWindow extends ChangeNotifier {
  AmplitudeWindow({this.capacity = 96, this.smoothing = 0.35})
    : _ring = Float64List(capacity),
      _fixed = null;

  /// A window that never changes: partner marks, history thumbnails, and the
  /// stored envelope of a finished session (R7.5.2).
  ///
  /// Notifies nothing, so a painter bound to it is never asked to repaint —
  /// which is what keeps a list of history rows from running a ticker each.
  AmplitudeWindow.fixed(List<double> values)
    : _fixed = List.unmodifiable(values),
      _ring = Float64List(0),
      capacity = 0,
      smoothing = 0;

  /// How many samples are retained. At 60fps, 96 samples is a 1.6s window —
  /// long enough to read as a waveform, short enough to feel live.
  final int capacity;

  /// Easing factor per frame, `0..1`. Higher follows the microphone faster and
  /// looks jumpier.
  final double smoothing;

  final Float64List _ring;
  final List<double>? _fixed;

  int _head = 0;
  int _filled = 0;
  double _target = 0;
  double _current = 0;

  bool get isFixed => _fixed != null;

  /// True when there is real data to draw. False means the painter should
  /// synthesise its idle wave instead.
  bool get hasData => isFixed ? _fixed!.isNotEmpty : _filled > 0;

  /// Records a new microphone reading, `0.0..1.0`.
  ///
  /// Does not notify. The reading becomes visible on the next [advance], which
  /// is one frame away at most — notifying here as well would schedule a
  /// repaint outside the ticker's rhythm for no visual benefit.
  void push(double amplitude) {
    if (isFixed) return;
    _target = amplitude.clamp(0.0, 1.0);
  }

  /// Advances one frame. Called by the Waveform's single ticker.
  ///
  /// Returns true if anything changed, so a silent window can stop notifying
  /// rather than repainting an unchanging picture sixty times a second — which
  /// matters for R11.4's battery budget over a twenty-minute session.
  bool advance() {
    if (isFixed) return false;

    final next = _current + (_target - _current) * smoothing;
    // Below a quarter of a percent the change is under one physical pixel at
    // any realistic waveform height, so it is not worth a frame.
    final settled = (next - _current).abs() < 0.0025 && _filled == capacity;
    _current = next;

    _ring[_head] = _current;
    _head = (_head + 1) % capacity;
    if (_filled < capacity) _filled++;

    if (settled && _target == 0 && _current < 0.0025) return false;

    notifyListeners();
    return true;
  }

  /// The amplitude at normalised position [t] (`0.0` oldest, `1.0` newest).
  double sample(double t) {
    final fixed = _fixed;
    if (fixed != null) {
      if (fixed.isEmpty) return 0;
      final index = ((fixed.length - 1) * t).round().clamp(0, fixed.length - 1);
      return fixed[index].clamp(0.0, 1.0);
    }

    if (_filled == 0) return 0;
    // Oldest sample sits at _head when full, at 0 while filling.
    final oldest = _filled == capacity ? _head : 0;
    final offset = ((_filled - 1) * t).round().clamp(0, _filled - 1);
    return _ring[(oldest + offset) % capacity];
  }

  /// Empties the window — between sessions, and whenever the microphone
  /// closes, so a paused session does not keep showing the last thing heard.
  void reset() {
    if (isFixed) return;
    _head = 0;
    _filled = 0;
    _target = 0;
    _current = 0;
    notifyListeners();
  }

  /// A snapshot, for the stored session envelope (§9.5 `sessions.metrics`) and
  /// for tests. Allocates, so it is never called from `paint`.
  List<double> toList([int bars = 48]) => [
    for (var i = 0; i < bars; i++) sample(bars == 1 ? 0 : i / (bars - 1)),
  ];
}
