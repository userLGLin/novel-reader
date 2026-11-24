import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

/// 一本书的元数据（正文单独存储，这里只存小字段）
class Book {
  final String id;
  final String title;
  final int addedAt;
  int lastReadAt;
  int chapterIndex; // 上次读到的章节
  int charOffset; // 章节内字符偏移
  int absOffset; // 全书字符偏移（用于算百分比）
  int totalChars;

  Book({
    required this.id,
    required this.title,
    required this.addedAt,
    required this.lastReadAt,
    this.chapterIndex = 0,
    this.charOffset = 0,
    this.absOffset = 0,
    this.totalChars = 0,
  });

  double get progress =>
      totalChars <= 0 ? 0 : (absOffset / totalChars).clamp(0.0, 1.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'addedAt': addedAt,
        'lastReadAt': lastReadAt,
        'chapterIndex': chapterIndex,
        'charOffset': charOffset,
        'absOffset': absOffset,
        'totalChars': totalChars,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        addedAt: j['addedAt'] as int,
        lastReadAt: j['lastReadAt'] as int,
        chapterIndex: j['chapterIndex'] as int? ?? 0,
        charOffset: j['charOffset'] as int? ?? 0,
        absOffset: j['absOffset'] as int? ?? 0,
        totalChars: j['totalChars'] as int? ?? 0,
      );
}

/// 章节：标题 + 在全书文本中的起止偏移
class Chapter {
  final String title;
  final int start;
  final int end;
  const Chapter(this.title, this.start, this.end);
}

/// TXT 解码：优先 UTF-8（含 BOM），失败回退 GBK/GB2312
String decodeTxt(Uint8List bytes) {
  var b = bytes;
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
    b = Uint8List.sublistView(b, 3);
  }
  String text;
  try {
    text = utf8.decode(b);
  } catch (_) {
    text = gbk.decode(b);
  }
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1);
  }
  // 部分 TXT 用连续空格（而非换行）分隔段落，转成换行以便正常排版
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), '\n');
  return text;
}

final RegExp _chapterTitleRe = RegExp(
  // 支持："第X章 标题"、"X章 标题"（无"第"）、"X 标题"（数字+空格）、序章/楔子/尾声/番外
  r'^[ \t　]{0,8}(第?[0-9零一二三四五六七八九十百千万两]{1,8}[章回节卷集部篇](?:[ \t　:：、·•\-—]+[^\n]{1,28})?|[0-9零一二三四五六七八九十百千万两]{1,8}[ \t　]+[^\n]{1,28}|序章[^\n]{0,30}|楔子[^\n]{0,30}|尾声[^\n]{0,30}|番外[^\n]{0,40})[ \t　]*$',
  multiLine: true,
);

/// 按“第X章/回/卷…”等标题行切分章节；识别不出来就按篇幅均分
List<Chapter> splitChapters(String text) {
  final matches = _chapterTitleRe.allMatches(text).toList();
  if (matches.length >= 2) {
    final chapters = <Chapter>[];
    if (matches.first.start > 0 &&
        text.substring(0, matches.first.start).trim().isNotEmpty) {
      chapters.add(Chapter('开头', 0, matches.first.start));
    }
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      final title = (m.group(1) ?? '').trim();
      chapters.add(Chapter(title.isEmpty ? '第 ${i + 1} 章' : title, m.start, end));
    }
    return chapters;
  }
  // 兜底：约 6000 字一节，尽量在换行处断开
  final chapters = <Chapter>[];
  var pos = 0;
  var n = 1;
  while (pos < text.length) {
    var cut = (pos + 6000).clamp(0, text.length);
    if (cut < text.length) {
      final nl = text.lastIndexOf('\n', cut);
      if (nl > pos + 4000) cut = nl + 1;
    }
    chapters.add(Chapter('第 $n 节', pos, cut));
    pos = cut;
    n++;
  }
  if (chapters.isEmpty) chapters.add(const Chapter('正文', 0, 0));
  return chapters;
}