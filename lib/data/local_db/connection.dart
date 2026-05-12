// lib/data/local_db/connection.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

LazyDatabase driftDatabase({required String name}) {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, '$name.sqlite'));

    if (kDebugMode) {
      // ignore: avoid_print
      print('📦 Drift DB path: ${file.path}');
    }

    return NativeDatabase(file, logStatements: kDebugMode);
  });
}