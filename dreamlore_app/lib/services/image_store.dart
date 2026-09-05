import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where generated dream pictures live: one JPEG per dream, in the app's own
/// documents directory. Local-only, like the journal itself.
class ImageStore {
  /// Overrides the storage root. Only tests pass this: it lets the naming and
  /// cleanup rules be exercised without a platform channel, which is the whole
  /// reason the stale-image bug shipped unnoticed.
  final Directory? root;
  const ImageStore({this.root});

  Future<Directory> _dir() async {
    final base = root ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'dream_images'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes [bytes] for [dreamId] and returns the file path to store.
  ///
  /// The filename carries a timestamp, and that is the whole point. Flutter's
  /// image cache keys a FileImage on its PATH, not on the file's contents or
  /// mtime, so writing a regenerated picture back to `<dreamId>.jpg` left the
  /// previously decoded image in the cache and the app redisplayed the old
  /// picture — "Paint again" appeared to do nothing, or to produce the same
  /// image every time. A fresh path is a fresh cache key.
  Future<String> save(String dreamId, Uint8List bytes) async {
    final file = File(
      p.join(
        (await _dir()).path,
        '${dreamId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> delete(String path) async {
    if (path.isEmpty) return;
    try {
      // Drop the decoded copy as well as the file. Unique names already stop
      // the stale-image bug; evicting keeps the cache from holding bytes for a
      // picture that no longer exists.
      await FileImage(File(path)).evict();
    } catch (_) {
      // Eviction is housekeeping, never a reason to fail a delete.
    }
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // A stale path is not worth surfacing.
    }
  }

  /// Removes every picture left behind for [dreamId]. Unique filenames mean a
  /// regeneration that crashed between writing and saving the new path would
  /// otherwise orphan a file nothing points at.
  Future<void> deleteAllFor(String dreamId) async {
    try {
      final dir = await _dir();
      await for (final e in dir.list()) {
        if (e is File && p.basename(e.path).startsWith('${dreamId}_')) {
          await delete(e.path);
        }
      }
    } catch (_) {
      // Best effort.
    }
  }
}
