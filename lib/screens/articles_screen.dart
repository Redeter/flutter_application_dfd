import 'package:flutter/material.dart';

class ArticlesScreen extends StatelessWidget {
  const ArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF7954A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Статьи',
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 20,
          ),
        ),
      ),
      body: Center(
        child: Text(
          'Статьи',
          style: TextStyle(
            fontSize: 24,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
