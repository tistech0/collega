import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
}
