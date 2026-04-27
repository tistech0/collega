import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/app.dart';

void main() {
  // Aucun provider bloquant ici — lazy init Riverpod (NFR4 : startup < 3s)
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
