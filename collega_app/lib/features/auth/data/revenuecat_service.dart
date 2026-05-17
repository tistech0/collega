import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class RevenueCatSubscriptionInfo {
  const RevenueCatSubscriptionInfo({
    required this.expirationDate,
    required this.willRenew,
  });
  final DateTime? expirationDate;
  final bool willRenew;
}

class RevenueCatService {
  Future<Package?> getMonthlyOffering() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.monthly;
    } catch (_) {
      return null;
    }
  }

  Future<PurchaseResult> purchaseMonthlySubscription(Package package) =>
      Purchases.purchase(PurchaseParams.package(package));

  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  Future<void> openSubscriptionManagement() async {
    final uri = Uri.parse('itms-apps://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<RevenueCatSubscriptionInfo?> getSubscriptionInfo() async {
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
