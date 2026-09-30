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
///
/// Idle teardown: with [idleGrace] set, the upstream subscription is closed
/// once the last listener has been gone that long (a quick return to the screen
/// still gets the cached value instantly). Streams keyed by something that
/// grows — one per order or ticket — need this so they don't each hold a
/// billed Firestore listener open for the rest of the session.
class SharedStream<T> {
  SharedStream(
    this._source, {
    this.retryDelay = const Duration(seconds: 5),
    this.idleGrace,
  });

  final Stream<T> Function() _source;
  final Duration retryDelay;
  final Duration? idleGrace;
  int _listeners = 0;
  Timer? _idleTimer;
  final StreamController<T> _controller = StreamController<T>.broadcast();
  StreamSubscription<T>? _upstream;
  Timer? _retryTimer;
  T? _latest;
  bool _hasLatest = false;
  bool _disposed = false;

  late final Stream<T> stream = Stream<T>.multi((listener) {
    _listeners++;
    _idleTimer?.cancel();
    _connect();
    if (_hasLatest) listener.add(_latest as T);
    final inner = _controller.stream.listen(listener.add, onError: listener.addError);
    listener.onCancel = () {
      _listeners--;
      _scheduleIdleTeardown();
      return inner.cancel();
    };
  }, isBroadcast: true);

  void _scheduleIdleTeardown() {
    final grace = idleGrace;
    if (grace == null || _listeners > 0 || _disposed) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(grace, () {
      if (_listeners == 0) {
        _retryTimer?.cancel();
        _dropUpstream();
      }
    });
  }

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
    _idleTimer?.cancel();
    _dropUpstream();
  }

  /// Retry now: drops a dead or stale subscription and, if anyone is
  /// listening, reconnects immediately instead of waiting for [retryDelay].
  /// Backs the "Retry" buttons on error states.
  void reconnect() {
    _retryTimer?.cancel();
    _dropUpstream();
    if (_listeners > 0) _connect();
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _idleTimer?.cancel();
    _dropUpstream();
    _controller.close();
  }
}

/// One [SharedStream] per key (an order id, a user id, ...), each handed back
/// as the same stable stream on every call — so a screen may call
/// `provider.streamX(id)` straight from `build()` without opening a fresh
/// Firestore listener per rebuild. Upstreams close after [idleGrace] with no
/// listeners.
class KeyedSharedStreams<K, T> {
  KeyedSharedStreams(
    this._source, {
    this.idleGrace = const Duration(seconds: 30),
    this.retryDelay = const Duration(seconds: 5),
  });

  final Stream<T> Function(K key) _source;
  final Duration idleGrace;
  final Duration retryDelay;
  final Map<K, SharedStream<T>> _streams = {};

  Stream<T> stream(K key) => (_streams[key] ??= SharedStream<T>(
        () => _source(key),
        idleGrace: idleGrace,
        retryDelay: retryDelay,
      ))
      .stream;

  /// Reconnects the stream for [key] now (a Retry button).
  void reconnect(K key) => _streams[key]?.reconnect();

  /// Drops every upstream and cached value (sign-out / user switch).
  void reset() {
    for (final shared in _streams.values) {
      shared.dispose();
    }
    _streams.clear();
  }

  void dispose() => reset();
}
