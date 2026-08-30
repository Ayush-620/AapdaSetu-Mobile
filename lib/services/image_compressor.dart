import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  ImageCompressor._();

  static Future<File> compress({
    required File file,
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 70,
  }) async {
    final beforeBytes = await file.length();

    if (kDebugMode) {
      debugPrint(
        '📸 Image size BEFORE compression: '
        '${_bytesToMB(beforeBytes)} MB',
      );
    }

    final tempDir = await getTemporaryDirectory();

    final targetPath = p.join(
      tempDir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final compressed = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Image compression failed. Using original image.');
      }

      return file;
    }

    final compressedFile = File(compressed.path);

    final afterBytes = await compressedFile.length();

    if (kDebugMode) {
      debugPrint(
        '✅ Image size AFTER compression: '
        '${_bytesToMB(afterBytes)} MB',
      );

      debugPrint(
        '📉 Compression reduced size by '
        '${((beforeBytes - afterBytes) / (1024 * 1024)).toStringAsFixed(2)} MB',
      );
    }

    return compressedFile;
  }

  static String _bytesToMB(int bytes) {
    return (bytes / (1024 * 1024)).toStringAsFixed(2);
  }
}
