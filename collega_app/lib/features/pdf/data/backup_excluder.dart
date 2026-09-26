import 'package:flutter/services.dart';

/// Retire un fichier de la sauvegarde iCloud (partie B) : un PDF de 400 Mo se
/// retélécharge, il ne doit pas remplir la sauvegarde de l'iPhone.
abstract interface class BackupExcluder {
  Future<void> exclude(String path);
}

class ChannelBackupExcluder implements BackupExcluder {
  const ChannelBackupExcluder();

  static const _channel = MethodChannel('collega/backup');

  @override
  Future<void> exclude(String path) => _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
}

class NoopBackupExcluder implements BackupExcluder {
  const NoopBackupExcluder();

  @override
  Future<void> exclude(String path) async {}
}
