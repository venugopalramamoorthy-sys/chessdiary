import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> platformSaveFile(
    String filename, List<int> bytes, String mimeType) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}
