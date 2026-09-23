import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_apns_only/flutter_apns_only.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/utils/logger.dart';

class NotificationsService {
  NotificationsService({required this.dio, required this.router});

  final Dio dio;
  final GoRouter router;

  ApnsPushConnectorOnly? _connector;

  /// Configure APNs (une fois) puis demande l'autorisation ; `true` si les
  /// notifications sont permises (iOS ne redemande pas une décision déjà prise).
  Future<bool> requestPermissionsAndRegister() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    if (_connector == null) {
      final connector = _connector = ApnsPushConnectorOnly();
      connector.configureApns(
        onLaunch: _onNotificationTap,
        onResume: _onNotificationTap,
        onMessage: (message) async {
          AppLogger.info('Notification reçue (foreground)', tag: 'NotificationsService');
        },
      );
      connector.token.addListener(() {
        final token = connector.token.value;
        if (token != null) _registerToken(token);
      });
    }
    return _connector!.requestNotificationPermissions();
  }

  Future<void> _onNotificationTap(ApnsRemoteMessage message) async {
    final collegeRefId = message.payload['college_ref_id'];
    if (collegeRefId == null) return;
    try {
      router.go('/colleges/$collegeRefId');
    } catch (e) {
      AppLogger.error('Navigation depuis notification échouée', tag: 'NotificationsService', error: e);
    }
  }

  // P10: reset pour permettre la ré-initialisation après logout/login
  void reset() {
    _connector = null;
  }

  Future<void> setReminder(int hourUtc) async {
    try {
      await dio.post<void>(
        '/v1/notifications/reminder',
        data: {'hour_utc': hourUtc},
      );
      AppLogger.info('Rappel configuré à ${hourUtc}h UTC', tag: 'NotificationsService');
    } on DioException catch (e) {
      AppLogger.error('Échec setReminder', tag: 'NotificationsService', error: e);
      rethrow;
    }
  }

  Future<void> clearReminder() async {
    try {
      await dio.delete<void>('/v1/notifications/reminder');
      AppLogger.info('Rappel désactivé', tag: 'NotificationsService');
    } on DioException catch (e) {
      AppLogger.error('Échec clearReminder', tag: 'NotificationsService', error: e);
      rethrow;
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await dio.post<void>(
        '/v1/notifications/apns-token',
        data: {'token': token},
      );
      AppLogger.info('APNs token enregistré', tag: 'NotificationsService');
    } on DioException catch (e) {
      // P12: distinguer le 401 (JWT expiré) des autres erreurs réseau
      if (e.response?.statusCode == 401) {
        AppLogger.warning(
          'APNs token non enregistré — JWT expiré, réessaiera au prochain refresh',
          tag: 'NotificationsService',
        );
      } else {
        AppLogger.error('Échec enregistrement token APNs', tag: 'NotificationsService', error: e);
      }
    } catch (e) {
      AppLogger.error('Échec enregistrement token APNs', tag: 'NotificationsService', error: e);
    }
  }
}

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  final router = ref.read(routerProvider);
  return NotificationsService(dio: dio, router: router);
});
