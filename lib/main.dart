import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: '모아북',
      home: Scaffold(
        body: Center(child: Text('모아북')),
      ),
    );
  }
}
