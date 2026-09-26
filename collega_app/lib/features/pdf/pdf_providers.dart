import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:collega_app/features/pdf/data/backup_excluder.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';

/// Copies locales des PDF (partie B), dans Application Support (jamais purgé par
/// iOS, contrairement aux caches), exclues de la sauvegarde iCloud.
final localPdfStoreProvider = FutureProvider<LocalPdfStore>((ref) async {
  final support = await getApplicationSupportDirectory();
  return LocalPdfStore(Directory(p.join(support.path, 'pdfs')), excluder: const ChannelBackupExcluder());
});
