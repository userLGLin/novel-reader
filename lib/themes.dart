import 'package:flutter/material.dart';

/// 阅读背景主题
class ReaderTheme {
  final String label;
  final Color bg;
  final Color fg;
  final Color sub;
  final Color panel;
  final Brightness brightness;
  const ReaderTheme(this.label, this.bg, this.fg, this.sub, this.panel, this.brightness);
}

const readerThemes = <ReaderTheme>[
  ReaderTheme('纸白', Color(0xFFFAFAFA), Color(0xFF2B2B2B), Color(0xFF9E9E9E),
      Color(0xFFF0F0F0), Brightness.light),
  ReaderTheme('米黄', Color(0xFFF5EFE0), Color(0xFF4A4033), Color(0xFFA89B85),
      Color(0xFFEDE5D2), Brightness.light),
  ReaderTheme('豆绿', Color(0xFFCCE8CF), Color(0xFF2F4F2F), Color(0xFF7FA882),
      Color(0xFFBDDCC0), Brightness.light),
  ReaderTheme('夜间', Color(0xFF121212), Color(0xFF9E9E9E), Color(0xFF5C5C5C),
      Color(0xFF1E1E1E), Brightness.dark),
];