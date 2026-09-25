import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Config de publication iOS (beta TestFlight) : push, chiffrement, signature.
// Chemins relatifs à collega_app (flutter test s'y exécute).
void main() {
  String read(String path) => File(path).readAsStringSync();

  test('entitlements : aps-environment (push)', () {
    final entitlements = read('ios/Runner/Runner.entitlements');
    expect(entitlements, contains('<key>aps-environment</key>'));
    expect(entitlements, contains('<string>development</string>'));
  });

  test('entitlements référencés dans les 3 configurations du target Runner', () {
    final pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');
    expect(
      'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'.allMatches(pbxproj).length,
      3,
    );
    expect(pbxproj, contains('path = Runner.entitlements;'));
  });

  test('Info.plist : chiffrement exempté et notifications distantes en arrière-plan', () {
    final plist = read('ios/Runner/Info.plist');
    expect(plist, matches(RegExp(r'<key>ITSAppUsesNonExemptEncryption</key>\s*<false/>')));
    expect(
      plist,
      matches(RegExp(r'<key>UIBackgroundModes</key>\s*<array>\s*<string>remote-notification</string>')),
    );
  });

  test('ExportOptions.plist : envoi App Store Connect, signature automatique', () {
    final options = read('ios/ExportOptions.plist');
    expect(options, matches(RegExp(r'<key>method</key>\s*<string>app-store-connect</string>')));
    expect(options, matches(RegExp(r'<key>signingStyle</key>\s*<string>automatic</string>')));
  });
}
