import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 本地存储：书籍元数据/设置放 SharedPreferences；
/// 正文在移动端存应用 Documents 目录的文件，Web 预览时存 prefs（仅供调试）。
class Store {
  Store._();
  static final Store instance = Store._();

  late SharedPreferences _prefs;
  final List<Book> books = [];

  /// 数据版本号：书籍增删或进度变化时自增，各页据此刷新
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 最近打开书籍的正文本缓存（最多 2 本），重开秒进
  final Map<String, String> _textCache = {};

  double fontSize = 18;
  int themeIndex = 0;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    fontSize = (_prefs.getDouble('fontSize') ?? 18).clamp(12, 32);
    themeIndex = (_prefs.getInt('themeIndex') ?? 0).clamp(0, 3);
    final raw = _prefs.getString('books');
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => Book.fromJson(e as Map<String, dynamic>))
            .toList();
        books.addAll(list);
      } catch (_) {}
    }
    _sort();
  }

  void _sort() {
    books.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt));
  }

  Future<void> _saveBooks() async {
    _sort();
    await _prefs.setString('books', jsonEncode(books.map((b) => b.toJson()).toList()));
  }

  Future<void> setFontSize(double v) async {
    fontSize = v.clamp(12, 32);
    await _prefs.setDouble('fontSize', fontSize);
  }

  Future<void> setThemeIndex(int i) async {
    themeIndex = i.clamp(0, 3);
    await _prefs.setInt('themeIndex', themeIndex);
  }

  Future<Directory> _booksDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/books');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Book> importTxt(String fileName, Uint8List bytes) async {
    final text = decodeTxt(bytes);
    if (text.trim().isEmpty) {
      throw Exception('文件内容为空或无法识别编码');
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (kIsWeb) {
      await _prefs.setString('text_$id', text);
    } else {
      final dir = await _booksDir();
      await File('${dir.path}/$id.txt').writeAsString(text, flush: true);
    }
    var title = fileName.split(RegExp(r'[\\/]')).last;
    if (title.toLowerCase().endsWith('.txt')) {
      title = title.substring(0, title.length - 4);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final chapters = splitChapters(text);
    final book = Book(
      id: id,
      title: title.isEmpty ? '未命名' : title,
      author: _extractAuthor(text),
      chapterTitles: [for (final c in chapters) c.title],
      chapterStarts: [for (final c in chapters) c.start],
      addedAt: now,
      lastReadAt: now,
      totalChars: text.length,
    );
    books.add(book);
    await _saveBooks();
    revision.value++;
    return book;
  }

  /// 取章节表：优先用导入时存好的，没有（老数据）就现算并回写
  List<Chapter> chaptersFor(Book book, String text) {
    final titles = book.chapterTitles;
    final starts = book.chapterStarts;
    if (titles != null &&
        starts != null &&
        titles.isNotEmpty &&
        titles.length == starts.length) {
      return [
        for (var i = 0; i < starts.length; i++)
          Chapter(titles[i], starts[i],
              i + 1 < starts.length ? starts[i + 1] : text.length)
      ];
    }
    final chapters = splitChapters(text);
    book.chapterTitles = [for (final c in chapters) c.title];
    book.chapterStarts = [for (final c in chapters) c.start];
    _saveBooks();
    return chapters;
  }

  /// 从正文开头找 "作者：xxx"
  static String? _extractAuthor(String text) {
    final head = text.substring(0, text.length < 3000 ? text.length : 3000);
    final m = RegExp(r'作\s*者\s*[:：]\s*([^\n]{1,30})').firstMatch(head);
    final name = m?.group(1)?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<String> loadText(Book book) async {
    final hit = _textCache.remove(book.id);
    if (hit != null) {
      _textCache[book.id] = hit;
      return hit;
    }
    String text;
    if (kIsWeb) {
      text = _prefs.getString('text_${book.id}') ?? '';
    } else {
      final dir = await _booksDir();
      text = await File('${dir.path}/${book.id}.txt').readAsString();
    }
    _textCache[book.id] = text;
    while (_textCache.length > 2) {
      _textCache.remove(_textCache.keys.first);
    }
    return text;
  }

  Future<void> delete(Book book) async {
    books.removeWhere((b) => b.id == book.id);
    _textCache.remove(book.id);
    if (kIsWeb) {
      await _prefs.remove('text_${book.id}');
    } else {
      final dir = await _booksDir();
      final f = File('${dir.path}/${book.id}.txt');
      if (await f.exists()) await f.delete();
    }
    await _saveBooks();
    revision.value++;
  }

  Future<void> saveProgress(
    Book book, {
    required int chapterIndex,
    required int charOffset,
    required int absOffset,
    String? chapterTitle,
  }) async {
    book.chapterIndex = chapterIndex;
    book.charOffset = charOffset;
    book.absOffset = absOffset;
    if (chapterTitle != null && chapterTitle.isNotEmpty) {
      book.chapterTitle = chapterTitle;
    }
    book.lastReadAt = DateTime.now().millisecondsSinceEpoch;
    await _saveBooks();
    revision.value++;
  }
}