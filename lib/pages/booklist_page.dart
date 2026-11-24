import 'package:flutter/material.dart';

class BooklistPage extends StatelessWidget {
  const BooklistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('书单',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_add_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('书单功能开发中',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            SizedBox(height: 6),
            Text('先专注读书吧，后续版本支持自定义书单',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}