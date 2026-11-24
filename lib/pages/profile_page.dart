import 'package:flutter/material.dart';

import '../store.dart';
import '../themes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _store = Store.instance;

  @override
  Widget build(BuildContext context) {
    final theme = readerThemes[_store.themeIndex];
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('阅读设置',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('字号', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                      onPressed: () async {
                        await _store.setFontSize(_store.fontSize - 2);
                        setState(() {});
                      },
                    ),
                    SizedBox(
                      width: 28,
                      child: Text('${_store.fontSize.round()}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      onPressed: () async {
                        await _store.setFontSize(_store.fontSize + 2);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('背景', style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    for (var i = 0; i < readerThemes.length; i++)
                      GestureDetector(
                        onTap: () async {
                          await _store.setThemeIndex(i);
                          setState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 12),
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: readerThemes[i].bg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == _store.themeIndex
                                  ? const Color(0xFFE53935)
                                  : Colors.grey.shade300,
                              width: i == _store.themeIndex ? 2 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '　　夜色渐深，书页翻动的声音轻得几乎听不见。预览效果随字号与背景实时变化。',
                    style: TextStyle(
                      fontSize: _store.fontSize,
                      height: 1.8,
                      color: theme.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('关于',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: const [
                ListTile(
                  dense: true,
                  leading: Icon(Icons.info_outline, size: 20),
                  title: Text('版本', style: TextStyle(fontSize: 14)),
                  trailing: Text('1.0.0',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.phone_iphone, size: 20),
                  title: Text('数据存储', style: TextStyle(fontSize: 14)),
                  trailing: Text('仅保存在本机',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),
                Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  dense: true,
                  leading: Icon(Icons.code, size: 20),
                  title: Text('开源仓库', style: TextStyle(fontSize: 14)),
                  trailing: Text('userLGLin/novel-reader',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}