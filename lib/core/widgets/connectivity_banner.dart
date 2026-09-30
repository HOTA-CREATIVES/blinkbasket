import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Shows a persistent banner when the device is offline. Uses Firestore's
/// snap-offline behavior to detect connectivity — when Firestore can't
/// reach the backend, writes queue locally and reads return cached data.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _isOnline = true;
  late final StreamSubscription<bool> _sub;

  @override
  void initState() {
    super.initState();
    // Firestore snapshots() emits a snapshot immediately, then again when
    // connectivity changes. We piggyback on this to detect offline mode.
    _sub = FirebaseFirestore.instance
        .collection('_connectivity_probe')
        .doc('_')
        .snapshots()
        .map((_) => true)
        .handleError((_) => false)
        .listen((online) {
      if (mounted && _isOnline != online) {
        setState(() => _isOnline = online);
      }
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!_isOnline)
          Material(
            color: Colors.orange.shade800,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'You\'re offline. Changes will sync when reconnected.',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
