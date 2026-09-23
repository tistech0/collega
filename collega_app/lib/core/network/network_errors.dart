import 'dart:io';

import 'package:dio/dio.dart';

/// Le réseau manque (pas le serveur) : c'est le seul cas où un écran dit
/// « Pas de connexion » ; un 500 ou un 401 reste une erreur (revue 8.6).
bool isNetworkUnreachable(Object error) {
  if (error is! DioException) return false;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      true,
    _ => error.error is SocketException,
  };
}
