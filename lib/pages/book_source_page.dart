import 'package:flutter/material.dart';

class BookSourcePage extends StatelessWidget {
  const BookSourcePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书源',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rss_feed, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('书源功能开发中',
                  style: TextStyle(fontSize: 15, color: Colors.grey)),
              SizedBox(height: 6),
              Text('当前为离线阅读器，仅支持本地 TXT 导入；\n后续版本可支持导入在线书源规则',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}