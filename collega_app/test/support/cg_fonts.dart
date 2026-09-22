import 'dart:io';

import 'package:flutter/services.dart';

import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Charge Instrument Sans (embarquée) dans le moteur de test : sans cela les
/// goldens seraient rendus en Ahem (carrés noirs).
Future<void> loadCgFonts() async {
  final loader = FontLoader(CgType.family);
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/InstrumentSans-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}
