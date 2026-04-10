import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;


Future<Uint8List> compressImageMobile(Uint8List bytes) async {
  final result = await FlutterImageCompress.compressWithList(
    bytes,
    quality: 70,
    minWidth: 1280,
    minHeight: 720,
  );
  return result;
}

Future<Uint8List> compressImageWeb(Uint8List bytes) async {
  final image = img.decodeImage(bytes);
  if (image == null) return bytes;

  final resized = img.copyResize(image, width: 1280);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
}

Future<Uint8List> compressImage(Uint8List bytes) async {
  if (kIsWeb) {
    return await compressImageWeb(bytes);
  } else {
    return await compressImageMobile(bytes);
  }
}