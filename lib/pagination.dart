import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 一页在全书/章节文本中的起止偏移
class PageSlice {
  final int start;
  final int end;
  const PageSlice(this.start, this.end);
}

/// 可增量推进的分页器：一次只算 maxPages 页，供"后台分帧预热"使用。
/// 用 TextPainter 实测排版，每页二分查找能塞进 maxLines 行的最大字符数。
class ChapterPaginator {
  ChapterPaginator(
    this.text, {
    required this.width,
    required this.height,
    required this.fontSize,
    this.lineHeightFactor = 1.8,
  }) : _style = TextStyle(fontSize: fontSize, height: lineHeightFactor) {
    if (text.isNotEmpty && width > 0 && height > 0) {
      final probe = _make('汉')..layout();
      _lineHeight = probe.preferredLineHeight;
      probe.dispose();
      _maxLines = math.max(1, (height / _lineHeight).floor());
      final charsPerLine = math.max(1, (width / fontSize).floor());
      _maxChars = charsPerLine * _maxLines;
    }
  }

  final String text;
  final double width;
  final double height;
  final double fontSize;
  final double lineHeightFactor;
  final TextStyle _style;

  double _lineHeight = 0;
  int _maxLines = 0;
  int _maxChars = 0;

  final List<PageSlice> pages = [];
  int _cursor = 0;

  bool get done => text.isEmpty ? pages.isNotEmpty : _cursor >= text.length;

  TextPainter _make(String s, {int? maxLines}) => TextPainter(
        text: TextSpan(text: s, style: _style),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
      );

  bool _fits(int start, int end) {
    final tp = _make(text.substring(start, end), maxLines: _maxLines)
      ..layout(maxWidth: width);
    final ok = !tp.didExceedMaxLines;
    tp.dispose();
    return ok;
  }

  /// 最多再计算 maxPages 页
  void advance(int maxPages) {
    if (text.isEmpty) {
      if (pages.isEmpty) pages.add(const PageSlice(0, 0));
      return;
    }
    if (width <= 0 || height <= 0) {
      if (pages.isEmpty) pages.add(PageSlice(0, text.length));
      _cursor = text.length;
      return;
    }
    var n = 0;
    while (_cursor < text.length && n < maxPages) {
      var hi = math.min(text.length, _cursor + _maxChars * 2 + 2);
      if (_fits(_cursor, hi)) {
        pages.add(PageSlice(_cursor, hi));
        _cursor = hi;
        n++;
        continue;
      }
      var lo = _cursor + 1;
      var best = _cursor + 1;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        if (_fits(_cursor, mid)) {
          best = mid;
          lo = mid + 1;
        } else {
          hi = mid - 1;
        }
      }
      pages.add(PageSlice(_cursor, best));
      _cursor = best;
      n++;
    }
  }
}

/// 一次性分完整个章节（页面显示的同步路径）
List<PageSlice> paginateChapter(
  String text, {
  required double width,
  required double height,
  required double fontSize,
  double lineHeightFactor = 1.8,
}) {
  final p = ChapterPaginator(
    text,
    width: width,
    height: height,
    fontSize: fontSize,
    lineHeightFactor: lineHeightFactor,
  );
  p.advance(1 << 30);
  if (p.pages.isEmpty) return const [PageSlice(0, 0)];
  return List.of(p.pages);
}