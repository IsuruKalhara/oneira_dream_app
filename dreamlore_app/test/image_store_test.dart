import 'dart:io';
import 'dart:typed_data';

import 'package:dreamlore_app/services/image_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression cover for a bug that reached a real device: every repaint wrote
/// to `<dreamId>.jpg`, and Flutter caches a FileImage by PATH, so the app kept
/// redisplaying the previous picture. The rule these tests hold in place is
/// that a new picture always lands on a new path.
void main() {
  late Directory tmp;
  late ImageStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('imgstore');
    store = ImageStore(root: tmp);
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Uint8List bytes(int fill) => Uint8List.fromList(List.filled(16, fill));

  test('repainting the same dream writes to a NEW path', () async {
    final first = await store.save('dream-1', bytes(1));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await store.save('dream-1', bytes(2));

    expect(second, isNot(equals(first)),
        reason: 'same path means Flutter serves the cached old image');
  });

  test('the newest file holds the newest bytes', () async {
    await store.save('dream-1', bytes(1));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await store.save('dream-1', bytes(2));

    expect(await File(second).readAsBytes(), equals(bytes(2)));
  });

  test('deleteAllFor removes every picture for that dream, and only that dream',
      () async {
    await store.save('dream-1', bytes(1));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.save('dream-1', bytes(2));
    final other = await store.save('dream-2', bytes(3));

    await store.deleteAllFor('dream-1');

    final left = await Directory('${tmp.path}/dream_images')
        .list()
        .map((e) => e.path)
        .toList();
    expect(left, [other]);
  });

  test('a repaint leaves exactly one file behind', () async {
    await store.save('dream-1', bytes(1));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.deleteAllFor('dream-1');
    await store.save('dream-1', bytes(2));

    final left = await Directory('${tmp.path}/dream_images').list().toList();
    expect(left, hasLength(1), reason: 'unique names must not orphan files');
  });

  test('delete on a path that is already gone is not an error', () async {
    final path = await store.save('dream-1', bytes(1));
    await store.delete(path);
    await store.delete(path);
    expect(await File(path).exists(), isFalse);
  });

  test('files are namespaced per dream', () async {
    final a = await store.save('dream-1', bytes(1));
    final b = await store.save('dream-2', bytes(2));
    expect(a, contains('dream-1_'));
    expect(b, contains('dream-2_'));
  });
}
