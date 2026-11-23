import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'reader_page.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final _store = Store.instance;
  bool _importing = false;

  Future<void> _import() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (f == null) return;
    setState(() => _importing = true);
    try {
      final bytes = await f.readAsBytes();
      final book = await _store.importTxt(f.name, bytes);
      if (mounted) {
        setState(() {});
        _toast('已导入《${book.title}》');
      }
    } catch (e) {
      if (mounted) _toast('导入失败：$e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _confirmDelete(Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这本书？'),
        content: Text('《${book.title}》和阅读进度将被删除，不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await _store.delete(book);
      if (mounted) setState(() {});
    }
  }

  void _open(Book book) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ReaderPage(book: book)))
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  String _fmtTime(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return '今天 ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.month}月${t.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final books = _store.books;
    return Scaffold(
      appBar: AppBar(title: const Text('书架')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: const Icon(Icons.add),
        label: const Text('导入 TXT'),
      ),
      body: Stack(
        children: [
          books.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '书架空空如也\n点右下角导入一本 TXT 小说吧\n\n支持 UTF-8 / GBK 编码\n自动识别章节，自动记住进度',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.8),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: books.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 76),
                  itemBuilder: (context, i) {
                    final b = books[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 44,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.brown.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          b.title.isEmpty ? '书' : b.title.characters.first,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(b.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '读到 ${(b.progress * 100).toStringAsFixed(1)}% · ${_fmtTime(b.lastReadAt)}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      onTap: () => _open(b),
                      onLongPress: () => _confirmDelete(b),
                    );
                  },
                ),
          if (_importing)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}