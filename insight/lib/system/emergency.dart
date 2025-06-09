import 'package:flutter/material.dart';

class Emergency extends StatelessWidget {
  const Emergency({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency'),
      ),
      body: const Center(
        child: Text(
          'Emergency screen coming soon...',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
