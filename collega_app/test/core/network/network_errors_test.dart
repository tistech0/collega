import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/network/network_errors.dart';

DioException _dio(DioExceptionType type, {Object? error}) =>
    DioException(requestOptions: RequestOptions(path: '/x'), type: type, error: error);

void main() {
  test('réseau injoignable : connexion, délais, socket', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      expect(isNetworkUnreachable(_dio(type)), isTrue, reason: '$type');
    }
    expect(isNetworkUnreachable(_dio(DioExceptionType.unknown, error: const SocketException('down'))), isTrue);
  });

  test('le serveur a répondu (500, 401) ou autre erreur : pas « hors connexion »', () {
    expect(isNetworkUnreachable(_dio(DioExceptionType.badResponse)), isFalse);
    expect(isNetworkUnreachable(_dio(DioExceptionType.cancel)), isFalse);
    expect(isNetworkUnreachable(StateError('x')), isFalse);
  });
}
