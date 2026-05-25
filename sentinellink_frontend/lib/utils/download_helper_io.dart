import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:path_provider/path_provider.dart';

Future<String?> downloadText(String fileName, String content) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return _androidSave(fileName, content.codeUnits);
  }
  final String? path = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar exportación',
    fileName: fileName,
    allowedExtensions: <String>['txt'],
    type: FileType.custom,
  );
  if (path == null) return null;
  await File(path).writeAsString(content);
  return path;
}

Future<String?> downloadBytes(String fileName, Uint8List bytes) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return _androidSave(fileName, bytes);
  }
  final String? path = await FilePicker.platform.saveFile(
    dialogTitle: 'Guardar archivo',
    fileName: fileName,
  );
  if (path == null) return null;
  await File(path).writeAsBytes(bytes);
  return path;
}

Future<String> _androidSave(String fileName, List<int> bytes) async {
  final Directory? ext = await getExternalStorageDirectory();
  final Directory dir = ext ?? await getApplicationDocumentsDirectory();
  final String path = '${dir.path}/$fileName';
  await File(path).writeAsBytes(bytes);
  return path;
}
