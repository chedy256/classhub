import 'package:flutter/material.dart';

class AddScreen extends StatelessWidget {
  final List<String> incomingUrls;
  const AddScreen({super.key, required this.incomingUrls});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Classhub')),
      body: ListView.builder(
        itemCount: incomingUrls.length,
        itemBuilder: (context, index) => ListTile(
          leading: const Icon(Icons.link),
          title: Text(
            incomingUrls[index],
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
