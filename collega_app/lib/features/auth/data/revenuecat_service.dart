import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:collega_app/env.dart';

class RevenueCatSubscriptionInfo {
  const RevenueCatSubscriptionInfo({
    required this.expirationDate,
    required this.willRenew,
  });
  final DateTime? expirationDate;
  final bool willRenew;
}

/// Levée par les actions d'achat quand RevenueCat est désactivé.
class RevenueCatDisabledException implements Exception {
  const RevenueCatDisabledException();
  @override
  String toString() => 'RevenueCatDisabledException: pas de clé iOS configurée';
}

/// Seul point d'entrée vers `Purchases.*` (hors `configure` dans main.dart).
/// Désactivé (pas de clé `appl_`) : aucun appel natif — offre et infos nulles,
/// logIn/logOut sans effet, achat/restauration en erreur.
class RevenueCatService {
  RevenueCatService({bool? enabled}) : enabled = enabled ?? kRevenueCatEnabled;

  final bool enabled;

  Future<void> logIn(String userId) async {
    if (!enabled) return;
    await Purchases.logIn(userId);
  }

  Future<void> logOut() async {
    if (!enabled) return;
    await Purchases.logOut();
  }

  Future<Package?> getMonthlyOffering() async {
    if (!enabled) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.monthly;
    } catch (_) {
      return null;
    }
  }

  Future<PurchaseResult> purchaseMonthlySubscription(Package package) async {
    if (!enabled) throw const RevenueCatDisabledException();
    return Purchases.purchase(PurchaseParams.package(package));
  }

  Future<CustomerInfo> restorePurchases() async {
    if (!enabled) throw const RevenueCatDisabledException();
    return Purchases.restorePurchases();
  }

  Future<void> openSubscriptionManagement() async {
    final uri = Uri.parse('itms-apps://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<RevenueCatSubscriptionInfo?> getSubscriptionInfo() async {
    if (!enabled) return null;
    try {
      final info = await Purchases.getCustomerInfo();
      final active = info.entitlements.active;
      if (active.isEmpty) return null;
      final entitlement = active.values.first;
      return RevenueCatSubscriptionInfo(
        expirationDate: entitlement.expirationDate != null
            ? DateTime.tryParse(entitlement.expirationDate!)
            : null,
        willRenew: entitlement.willRenew,
      );
    } catch (_) {
      return null;
    }
  }
}
