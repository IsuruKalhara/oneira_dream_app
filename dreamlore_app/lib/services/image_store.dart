import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where generated dream pictures live: one JPEG per dream, in the app's own
/// documents directory. Local-only, like the journal itself.
class ImageStore {
  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'dream_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes [bytes] for [dreamId] and returns the file path to store.
  Future<String> save(String dreamId, Uint8List bytes) async {
    final file = File(p.join((await _dir()).path, '$dreamId.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> delete(String path) async {
    if (path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // A stale path is not worth surfacing.
    }
  }
}
