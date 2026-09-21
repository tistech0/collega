import 'dart:io';

/// Découpe un fichier en morceaux `part_0..part_{N-1}` de [partSize] octets (le dernier plus court).
class PartSplitter {
  const PartSplitter._();

  /// Écrit les morceaux dans [dir] (créé si besoin) et renvoie les fichiers dans l'ordre.
  /// Avec [only], seuls les index listés sont produits (reprise après coupure).
  static Future<List<File>> split(
    File source,
    int partSize,
    Directory dir, {
    Set<int> only = const {},
  }) async {
    await dir.create(recursive: true);
    final length = await source.length();
    final total = (length + partSize - 1) ~/ partSize;
    final raf = await source.open();
    final out = <File>[];
    try {
      for (var n = 0; n < total; n++) {
        if (only.isNotEmpty && !only.contains(n)) continue;
        final start = n * partSize;
        final size = (n == total - 1) ? length - start : partSize;
        await raf.setPosition(start);
        final bytes = await raf.read(size);
        final f = File('${dir.path}/part_$n');
        await f.writeAsBytes(bytes, flush: true);
        out.add(f);
      }
    } finally {
      await raf.close();
    }
    return out;
  }
}
