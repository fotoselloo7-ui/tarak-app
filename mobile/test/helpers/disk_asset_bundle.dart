import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serves the bundled `assets/geo/**` location files straight from disk with synchronous reads, which is what the
/// asset bundle serves on a device and keeps widget tests (FakeAsync) from waiting on real file IO or isolates.
class DiskAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async => File(key).readAsStringSync();
}

/// A bundle that has none of the app's assets (simulates unreadable bundled location files).
class MissingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future<ByteData>.error(FlutterError('Unable to load asset: $key'));
}
