import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

// Copy an asset to a readable local file and return its absolute path.
// This is used by native platforms (Windows/macOS/Linux/Android/iOS).
Future<String> writeAssetToFile(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final dir = await getApplicationSupportDirectory();
  // Keep filename only to avoid creating deep directories
  final fileName = assetPath.split('/').last;
  final file = File('${dir.path}/$fileName');
  if (!await file.parent.exists()) {
    await file.parent.create(recursive: true);
  }
  await file.writeAsBytes(data.buffer.asUint8List());
  return file.path;
}