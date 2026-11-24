import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'store.dart';

/// 打开系统文件选择器导入一本 TXT。
/// 返回书名；用户取消返回 null；失败抛异常由调用方提示。
Future<String?> pickAndImportTxt(BuildContext context) async {
  final f = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['txt'],
  );
  if (f == null) return null;
  final bytes = await f.readAsBytes();
  final book = await Store.instance.importTxt(f.name, bytes);
  return book.title;
}

void showToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}

String formatWan(int chars) {
  if (chars < 10000) return '$chars 字';
  return '${(chars / 10000).toStringAsFixed(1)} 万字';
}