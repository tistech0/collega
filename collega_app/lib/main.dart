import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:collega_app/app.dart';
import 'package:collega_app/env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Story 7.11 : réactive le suivi des uploads de morceaux lancés en arrière-plan.
  await FileDownloader().start(autoCleanDatabase: true);
  await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
