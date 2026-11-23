import 'dart:convert';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/models.dart';
import 'package:novel_reader/pagination.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeTxt', () {
    test('UTF-8 正常解码', () {
      final bytes = Uint8List.fromList(utf8.encode('第一章 起点\n正文内容'));
      expect(decodeTxt(bytes), '第一章 起点\n正文内容');
    });

    test('UTF-8 BOM 被去掉', () {
      final bytes =
          Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('你好')]);
      expect(decodeTxt(bytes), '你好');
    });

    test('GBK 回退解码', () {
      final bytes = Uint8List.fromList(gbk.encode('第一章 测试\n中文内容'));
      expect(decodeTxt(bytes), '第一章 测试\n中文内容');
    });

    test('CRLF 归一化', () {
      final bytes = Uint8List.fromList(utf8.encode('a\r\nb\rc'));
      expect(decodeTxt(bytes), 'a\nb\nc');
    });
  });

  group('splitChapters', () {
    test('标准章节标题', () {
      const text = '引子内容\n第一章 开始\n正文一\n第二章 转折\n正文二\n第3章 高潮\n正文三';
      final chapters = splitChapters(text);
      expect(chapters.length, 4);
      expect(chapters[0].title, '开头');
      expect(chapters[1].title, '第一章 开始');
      expect(chapters[2].title, '第二章 转折');
      expect(chapters[3].title, '第3章 高潮');
      expect(text.substring(chapters[1].start, chapters[1].end),
          '第一章 开始\n正文一\n');
    });

    test('楔子/番外也能识别', () {
      const text = '楔子\n内容\n第一章 正文\n内容\n番外 后日谈\n内容';
      final chapters = splitChapters(text);
      expect(chapters.length, 3);
      expect(chapters[0].title, '楔子');
      expect(chapters[2].title, '番外 后日谈');
    });

    test('无章节标题时按篇幅兜底切分', () {
      final text = '一段文字。\n' * 2000;
      final chapters = splitChapters(text);
      expect(chapters.length, greaterThan(1));
      expect(chapters.first.start, 0);
      expect(chapters.last.end, text.length);
      // 章节连续无缝隙
      for (var i = 1; i < chapters.length; i++) {
        expect(chapters[i].start, chapters[i - 1].end);
      }
    });
  });

  group('paginateChapter', () {
    test('分页覆盖全文且无缝隙', () {
      final text = '这是测试正文。' * 500;
      final pages = paginateChapter(text,
          width: 300, height: 400, fontSize: 18);
      expect(pages.first.start, 0);
      expect(pages.last.end, text.length);
      for (var i = 1; i < pages.length; i++) {
        expect(pages[i].start, pages[i - 1].end);
      }
      expect(pages.length, greaterThan(1));
    });

    test('字号越大页数越多', () {
      final text = '这是测试正文。' * 500;
      final small = paginateChapter(text,
          width: 300, height: 400, fontSize: 14);
      final big = paginateChapter(text,
          width: 300, height: 400, fontSize: 28);
      expect(big.length, greaterThan(small.length));
    });

    test('空文本返回单页', () {
      final pages =
          paginateChapter('', width: 300, height: 400, fontSize: 18);
      expect(pages.length, 1);
    });
  });
}