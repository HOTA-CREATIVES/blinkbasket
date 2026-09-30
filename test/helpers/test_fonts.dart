import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flutter's test font (Ahem) draws every glyph a full em wide — roughly twice
/// as wide as a real font — so layout tests run in it report overflows that
/// no user would see (and hide ones they would). This loads Roboto from the
/// Flutter SDK, which is close to the app's real text metrics.
///
/// Returns false when the SDK fonts can't be found (the layout tests then skip
/// rather than assert against the wrong font).
Future<bool> loadRealisticFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return false;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return false;

  const files = {
    'Roboto-Regular.ttf': FontWeight.w400,
    'Roboto-Medium.ttf': FontWeight.w500,
    'Roboto-Bold.ttf': FontWeight.w700,
    'Roboto-Black.ttf': FontWeight.w900,
  };
  final loader = FontLoader('Roboto');
  var added = 0;
  for (final name in files.keys) {
    final file = File('${dir.path}/$name');
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    added++;
  }
  if (added == 0) return false;
  await loader.load();
  return true;
}

/// A MaterialApp on a 360x640 phone at [textScale], using the loaded font.
Widget testApp({required Widget home, double textScale = 1.0}) => MaterialApp(
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );
