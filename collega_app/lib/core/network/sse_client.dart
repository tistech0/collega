import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:collega_app/core/utils/logger.dart';

class SseClient {
  SseClient(this._baseUrl, {required String Function() tokenProvider})
      : _tokenProvider = tokenProvider,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(hours: 3),
        ));

  final String _baseUrl;
  final String Function() _tokenProvider;
  final Dio _dio;
  CancelToken? _cancelToken;

  Stream<Map<String, dynamic>> connect(String path) async* {
    _cancelToken?.cancel('reconnect');
    _cancelToken = CancelToken();

    try {
      final response = await _dio.get<ResponseBody>(
        '$_baseUrl$path',
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Authorization': 'Bearer ${_tokenProvider()}',
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        ),
        cancelToken: _cancelToken,
      );

      String buffer = '';
      await for (final chunk in response.data!.stream) {
        buffer += utf8.decode(chunk);
        final parts = buffer.split('\n\n');
        buffer = parts.removeLast();

        for (final part in parts) {
          String? dataLine;
          for (final line in part.split('\n')) {
            if (line.startsWith('data:')) {
              dataLine = line.substring(5).trim();
            }
          }
          if (dataLine != null && dataLine.isNotEmpty) {
            try {
              final json = jsonDecode(dataLine) as Map<String, dynamic>;
              yield json;
            } catch (_) {
              AppLogger.warning('SSE: JSON invalide dans la ligne data', tag: 'SseClient');
            }
          }
        }
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        AppLogger.error('SSE connection error', tag: 'SseClient', error: e);
        rethrow;
      }
    }
  }

  void disconnect() {
    _cancelToken?.cancel('disconnect');
    _cancelToken = null;
  }
}
