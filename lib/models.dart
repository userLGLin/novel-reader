import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

/// 一本书的元数据（正文单独存储，这里只存小字段）
class Book {
  final String id;
  final String title;
  final int addedAt;
  String? author;
  String? chapterTitle; // 上次读到的章节名（书架展示用）
  List<String>? chapterTitles; // 导入时预解析的章节表
  List<int>? chapterStarts;
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
    this.author,
    this.chapterTitle,
    this.chapterTitles,
    this.chapterStarts,
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
        'author': author,
        'chapterTitle': chapterTitle,
        'chapterTitles': chapterTitles,
        'chapterStarts': chapterStarts,
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
        author: j['author'] as String?,
        chapterTitle: j['chapterTitle'] as String?,
        chapterTitles: (j['chapterTitles'] as List?)?.cast<String>(),
        chapterStarts: (j['chapterStarts'] as List?)?.cast<int>(),
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
  // 正文段落统一首行缩进两字（章节标题行不动）
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    if (_chapterTitleRe.hasMatch(line)) {
      lines[i] = line.trim();
      continue;
    }
    final body = line.trimLeft();
    if (body.startsWith('　　')) continue;
    lines[i] = '　　$body';
  }
  text = lines.join('\n');
  return text;
}

final RegExp _chapterTitleRe = RegExp(
  // 支持："第X章 标题"、"X章 标题"（无"第"）、"X 标题"（数字+空格）、序章/楔子/尾声/番外
  r'^[ \t　]{0,8}(第?[0-9零一二三四五六七八九十百千万两]{1,8}[章回节卷集部篇](?:[ \t　:：、·•\-—]+[^\n]{1,28})?|[0-9零一二三四五六七八九十百千万两]{1,8}[ \t　]+[^\n]{1,28}|序章[^\n]{0,30}|楔子[^\n]{0,30}|尾声[^\n]{0,30}|番外[^\n]{0,40})[ \t　]*$',
  multiLine: true,
);

/// 按“第X章/回/卷…”等标题行切分章节；识别不出来就按篇幅均分。
/// 逐行扫描 + 每行短正则，避免在大文本上跑 multiline 正则（大书快一个量级）。
List<Chapter> splitChapters(String text) {
  final titles = <String>[];
  final starts = <int>[];
  var lineStart = 0;
  while (lineStart <= text.length) {
    final nl = text.indexOf('\n', lineStart);
    final lineEnd = nl < 0 ? text.length : nl;
    if (lineEnd > lineStart) {
      final title = _matchChapterTitle(text.substring(lineStart, lineEnd));
      if (title != null) {
        titles.add(title);
        starts.add(lineStart);
      }
    }
    if (nl < 0) break;
    lineStart = nl + 1;
  }
  if (titles.length >= 2) {
    final chapters = <Chapter>[];
    if (starts.first > 0 &&
        text.substring(0, starts.first).trim().isNotEmpty) {
      chapters.add(Chapter('开头', 0, starts.first));
    }
    for (var i = 0; i < titles.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] : text.length;
      chapters.add(Chapter(titles[i], starts[i], end));
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

const _numerals = '零一二三四五六七八九十百千万两';

/// 单行是否是章节标题，是则返回标题文本
String? _matchChapterTitle(String line) {
  var i = 0;
  while (i < line.length &&
      (line[i] == ' ' || line[i] == '\t' || line[i] == '　')) {
    i++;
  }
  if (i >= line.length) return null;
  final c = line[i];
  final code = c.codeUnitAt(0);
  final isDigit = code >= 0x30 && code <= 0x39;
  const specials = '第序楔尾番';
  if (!isDigit && !_numerals.contains(c) && !specials.contains(c)) {
    return null;
  }
  final m = _chapterTitleRe.firstMatch(line);
  if (m == null) return null;
  final title = (m.group(1) ?? '').trim();
  return title.isEmpty ? null : title;
}