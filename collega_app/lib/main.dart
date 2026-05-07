import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:collega_app/app.dart';
import 'package:collega_app/env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
