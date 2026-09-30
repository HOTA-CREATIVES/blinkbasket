import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Decides whether the app is offline from Firestore's own signal: a snapshot
/// served from the local cache that the server never confirms.
///
/// A snapshot is also `fromCache` for a moment on every cold start, before the
/// server answers, so "offline" is only declared once that has lasted for
/// [grace]. Any server-confirmed snapshot means online, immediately.
class OfflineDetector {
  OfflineDetector({
    required this.onChange,
    this.grace = const Duration(seconds: 4),
  });

  /// Called with `true` when the app is (back) online, `false` when offline.
  final void Function(bool online) onChange;
  final Duration grace;

  bool _online = true;
  Timer? _pending;

  bool get isOnline => _online;

  /// Feed each snapshot's `metadata.isFromCache`.
  void onSnapshot({required bool fromCache}) {
    if (!fromCache) {
      _pending?.cancel();
      _pending = null;
      _set(true);
      return;
    }
    if (!_online || _pending != null) return;
    _pending = Timer(grace, () {
      _pending = null;
      _set(false);
    });
  }

  void _set(bool online) {
    if (_online == online) return;
    _online = online;
    onChange(online);
  }

  void dispose() {
    _pending?.cancel();
    _pending = null;
  }
}

/// Shows a persistent banner when the device can't reach the backend.
///
/// Connectivity comes from a one-document listener on the public `products`
/// collection: readable with or without a sign-in, so the banner also works on
/// the login screen. (It used to probe a document the security rules deny, so
/// it never reported anything.)
class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  /// Emits each snapshot's `isFromCache`. Overridable for tests; the default
  /// listens to Firestore.
  final Stream<bool>? cacheStates;

  /// How long a cache-only state must last before the app is called offline.
  final Duration grace;

  const ConnectivityBanner({
    super.key,
    required this.child,
    this.cacheStates,
    this.grace = const Duration(seconds: 4),
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOnline = true;
  late final OfflineDetector _detector;
  StreamSubscription<bool>? _sub;

  static Stream<bool> _firestoreCacheStates() => FirebaseFirestore.instance
      .collection('products')
      .limit(1)
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => snapshot.metadata.isFromCache);

  @override
  void initState() {
    super.initState();
    _detector = OfflineDetector(
      grace: widget.grace,
      onChange: (online) {
        if (mounted) setState(() => _isOnline = online);
      },
    );
    _sub = (widget.cacheStates ?? _firestoreCacheStates()).listen(
      (fromCache) => _detector.onSnapshot(fromCache: fromCache),
      // A listener error (rules, auth flap) says nothing about connectivity.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          Semantics(
            liveRegion: true,
            child: Material(
              color: Colors.orange.shade800,
              child: SafeArea(
                bottom: false,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You're offline. Orders and live updates need a connection.",
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
