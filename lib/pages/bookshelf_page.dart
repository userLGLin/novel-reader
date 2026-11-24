import 'package:flutter/material.dart';

import '../import_action.dart';
import '../models.dart';
import '../store.dart';
import 'reader_page.dart';

const _coverPalettes = <List<Color>>[
  [Color(0xFF8D6E63), Color(0xFF4E342E)],
  [Color(0xFF7986CB), Color(0xFF303F9F)],
  [Color(0xFF4DB6AC), Color(0xFF00695C)],
  [Color(0xFFE57373), Color(0xFFB71C1C)],
  [Color(0xFF90A4AE), Color(0xFF455A64)],
  [Color(0xFF9575CD), Color(0xFF4527A0)],
];

class BookCover extends StatelessWidget {
  final String title;
  final double width;
  final double height;
  const BookCover(
      {super.key, required this.title, this.width = 60, this.height = 84});

  @override
  Widget build(BuildContext context) {
    final h = title.codeUnits.fold<int>(0, (a, b) => a + b);
    final colors = _coverPalettes[h % _coverPalettes.length];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      alignment: Alignment.topCenter,
      child: Text(
        title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: width / 6,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ),
    );
  }
}

class BookRow extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool compact;
  const BookRow({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final pct = book.progress * 100;
    if (compact) {
      return InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              BookCover(title: book.title, width: 42, height: 58),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '读到 ${book.chapterTitle ?? '尚未开始'} · ${pct.toStringAsFixed(1)}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(title: book.title, width: 60, height: 84),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (book.author != null)
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              book.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.bookmark_border,
                            size: 12, color: Colors.grey),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            '读到 ${book.chapterTitle ?? '尚未开始'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: book.progress,
                              minHeight: 3,
                              backgroundColor: Colors.grey.shade200,
                              color: const Color(0xFFE57373),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({super.key});

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> {
  final _store = Store.instance;
  bool _importing = false;

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final name = await pickAndImportTxt(context);
      if (name != null && mounted) showToast(context, '已导入《$name》');
    } catch (e) {
      if (mounted) showToast(context, '导入失败：$e');
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
    if (ok == true) await _store.delete(book);
  }

  void _open(Book book) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ReaderPage(book: book)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importing ? null : _import,
        icon: const Icon(Icons.add),
        label: const Text('导入 TXT'),
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _store.revision,
            builder: (context, _, __) {
              final books = _store.books;
              if (books.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      '书架空空如也\n点右下角导入一本 TXT 小说吧\n\n支持 UTF-8 / GBK 编码\n自动识别章节，自动记住进度',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.8),
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: books.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, i) {
                  final b = books[i];
                  return BookRow(
                    book: b,
                    onTap: () => _open(b),
                    onLongPress: () => _confirmDelete(b),
                  );
                },
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