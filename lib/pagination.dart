import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 一页在全书/章节文本中的起止偏移
class PageSlice {
  final int start;
  final int end;
  const PageSlice(this.start, this.end);
}

/// 用 TextPainter 实测排版，把章节文本切成一页页。
/// 每页用二分查找能塞进 maxLines 行的最大字符数，字号/屏幕变化后重新切。
List<PageSlice> paginateChapter(
  String text, {
  required double width,
  required double height,
  required double fontSize,
  double lineHeightFactor = 1.8,
}) {
  if (text.isEmpty || width <= 0 || height <= 0) {
    return const [PageSlice(0, 0)];
  }
  final style = TextStyle(fontSize: fontSize, height: lineHeightFactor);

  TextPainter make(String s, {int? maxLines}) => TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
      );

  final probe = make('汉')..layout();
  final lineHeight = probe.preferredLineHeight;
  probe.dispose();
  final maxLines = math.max(1, (height / lineHeight).floor());
  final charsPerLine = math.max(1, (width / fontSize).floor());
  final maxChars = charsPerLine * maxLines;

  bool fits(int start, int end) {
    final tp = make(text.substring(start, end), maxLines: maxLines)
      ..layout(maxWidth: width);
    final ok = !tp.didExceedMaxLines;
    tp.dispose();
    return ok;
  }

  final pages = <PageSlice>[];
  var start = 0;
  while (start < text.length) {
    var hi = math.min(text.length, start + maxChars * 2 + 2);
    if (fits(start, hi)) {
      pages.add(PageSlice(start, hi));
      start = hi;
      continue;
    }
    var lo = start + 1;
    var best = start + 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (fits(start, mid)) {
        best = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    pages.add(PageSlice(start, best));
    start = best;
  }
  return pages;
}