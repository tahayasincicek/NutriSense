import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Kişisel veri içeren bir dosyayı geçici klasöre yazar, paylaşım penceresini
/// açar ve paylaşım bitince dosyayı siler.
///
/// Sağlık kaydı ve araştırma verisi cihazda sahipsiz bir kopya olarak
/// kalmamalıdır. Android'de share_plus dosyayı kendi paylaşım klasörüne
/// kopyalar; iOS'ta paylaşım tamamlanana kadar bekler. Bu yüzden dosyayı
/// hemen silmek paylaşımı bozmaz.
Future<ShareResult> shareTemporaryFile({
  required String fileName,
  required String contents,
  Encoding encoding = utf8,
  String? subject,
  String? text,
}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  try {
    await file.writeAsString(contents, encoding: encoding);
    return await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject, text: text),
    );
  } finally {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
