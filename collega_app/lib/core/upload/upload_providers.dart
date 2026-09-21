import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/upload/background_part_transport.dart';
import 'package:collega_app/core/upload/chunked_upload_service.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_api.dart';

final uploadApiProvider = Provider<UploadApi>((ref) => DioUploadApi(dio: ref.read(apiClientProvider).dio));

final partTransportProvider = Provider<PartTransport>((_) => BackgroundPartTransport());

/// Répertoire des morceaux découpés (cache : purgeable par l'OS, recréé à la reprise).
final uploadCacheDirProvider = FutureProvider<Directory>((_) => getTemporaryDirectory());

final chunkedUploadServiceProvider = FutureProvider<ChunkedUploadService>((ref) async {
  return ChunkedUploadService(
    api: ref.read(uploadApiProvider),
    transport: ref.read(partTransportProvider),
    db: ref.read(databaseProvider),
    cacheDir: await ref.watch(uploadCacheDirProvider.future),
  );
});
