import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/env.dart';
import 'package:collega_app/features/auth/data/revenuecat_service.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Tout appel au canal natif RevenueCat est tracé : désactivé, il n'y en a aucun.
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('purchases_flutter'),
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('purchases_flutter'), null);
  });

  test('clé actuelle (pas appl_) : RevenueCat désactivé', () {
    expect(revenueCatApiKey.startsWith('appl_'), isFalse);
    expect(kRevenueCatEnabled, isFalse);
    expect(RevenueCatService().enabled, isFalse);
  });

  group('RevenueCatService désactivé : aucun appel natif', () {
    final service = RevenueCatService(enabled: false);

    test('offre et infos d’abonnement nulles', () async {
      expect(await service.getMonthlyOffering(), isNull);
      expect(await service.getSubscriptionInfo(), isNull);
      expect(calls, isEmpty);
    });

    test('logIn / logOut sans effet', () async {
      await service.logIn('uid-1');
      await service.logOut();
      expect(calls, isEmpty);
    });

    test('restaurer lève une erreur (le paywall affiche « restauration échouée »)', () async {
      await expectLater(service.restorePurchases(), throwsA(isA<RevenueCatDisabledException>()));
      expect(calls, isEmpty);
    });
  });

  test('activé : logIn / logOut passent par le canal natif', () async {
    final service = RevenueCatService(enabled: true);
    // Le mock renvoie null : le SDK échoue au décodage, seul l'appel compte.
    await service.logIn('uid-1').catchError((_) {});
    await service.logOut().catchError((_) {});
    expect(calls, ['logIn', 'logOut']);
  });

  test('bêta non abonnée : accès complet, jamais de paywall', () {
    const beta = AuthState(user: AuthUser(id: 'b', email: 'b@b.fr', isBeta: true, isSubscribed: false));
    expect(beta.hasAccess, isTrue);
  });
}
