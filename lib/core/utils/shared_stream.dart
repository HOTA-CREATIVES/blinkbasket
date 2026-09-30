import 'dart:async';

/// One shared upstream subscription fanned out to any number of listeners,
/// with the latest value replayed to late joiners.
///
/// Exposes a single, stable [stream] object. Screens that read a provider's
/// stream inside `build()` used to get a brand-new Firestore listener on every
/// rebuild (extra billed reads, and a StreamBuilder that re-subscribed and
/// briefly reported `waiting`). With this, rebuilding is free: the same stream
/// instance is handed back and the newest snapshot is delivered immediately.
///
/// Recovery: a Firestore listener that fails (permission denied after a
/// sign-out, a token flap) is dead for good. So on an upstream error the error
/// is forwarded, the dead subscription and cached value are dropped, and — if
/// anyone is still listening — the source is re-subscribed after
/// [retryDelay]. [reset] does the same on demand (e.g. on sign-out) so the
/// next user never sees the previous user's data.
class SharedStream<T> {
  SharedStream(this._source, {this.retryDelay = const Duration(seconds: 5)});

  final Stream<T> Function() _source;
  final Duration retryDelay;
  final StreamController<T> _controller = StreamController<T>.broadcast();
  StreamSubscription<T>? _upstream;
  Timer? _retryTimer;
  T? _latest;
  bool _hasLatest = false;
  bool _disposed = false;

  late final Stream<T> stream = Stream<T>.multi((listener) {
    _connect();
    if (_hasLatest) listener.add(_latest as T);
    final inner = _controller.stream.listen(listener.add, onError: listener.addError);
    listener.onCancel = inner.cancel;
  }, isBroadcast: true);

  void _connect() {
    if (_upstream != null || _disposed) return;
    _upstream = _source().listen(
      (value) {
        _latest = value;
        _hasLatest = true;
        _controller.add(value);
      },
      onError: (Object error, StackTrace stack) {
        _controller.addError(error, stack);
        _dropUpstream();
        _retryTimer?.cancel();
        _retryTimer = Timer(retryDelay, () {
          if (!_disposed && _controller.hasListener) _connect();
        });
      },
    );
  }

  void _dropUpstream() {
    _upstream?.cancel();
    _upstream = null;
    _latest = null;
    _hasLatest = false;
  }

  /// Forgets the upstream subscription and the cached value. The next listener
  /// (or a retry, if listeners remain) starts a fresh subscription.
  void reset() {
    _retryTimer?.cancel();
    _dropUpstream();
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _dropUpstream();
    _controller.close();
  }
}
