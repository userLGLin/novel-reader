import 'package:flutter/material.dart';

import '../import_action.dart';
import '../store.dart';
import 'bookshelf_page.dart';
import 'reader_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _store.revision,
            builder: (context, _, __) {
              final books = _store.books;
              final totalChars =
                  books.fold<int>(0, (a, b) => a + b.totalChars);
              final readChars = books.fold<int>(0, (a, b) => a + b.absOffset);
              final recent = books.take(3).toList();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Material(
                    color: const Color(0xFFFBE9E7),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _importing ? null : _import,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.add_circle_outline,
                                size: 36, color: Color(0xFFD84315)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('导入本地 TXT',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  SizedBox(height: 4),
                                  Text('UTF-8 / GBK 自动识别编码，自动切分章节',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('本机阅读数据',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _stat('书籍', '${books.length} 本'),
                      const SizedBox(width: 10),
                      _stat('总量', formatWan(totalChars)),
                      const SizedBox(width: 10),
                      _stat('已读', formatWan(readChars)),
                    ],
                  ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('最近在读',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    for (final b in recent)
                      BookRow(
                        book: b,
                        compact: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => ReaderPage(book: b)),
                        ),
                      ),
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      '全离线单机应用 · 不上传任何数据',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ],
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

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}