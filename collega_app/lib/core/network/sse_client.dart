// Stub SSE client — implémenté en Story 3.2
// Format events attendus : {"event": "...", "data": {...}}

class SseClient {
  SseClient(this._baseUrl);

  final String _baseUrl;

  // ignore: unused_field
  String get baseUrl => _baseUrl;

  Stream<Map<String, dynamic>> connect(String path) {
    throw UnimplementedError('SseClient.connect() implémenté en Story 3.2');
  }

  void disconnect() {}
}
