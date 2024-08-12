import 'package:flutter/material.dart';

class NoConnectionModal extends StatelessWidget {
  final VoidCallback onRetry;

  const NoConnectionModal({Key? key, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: const Text('No Internet Connection',
            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        content: const Text(
          'Please check your internet connection and try again.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Colors.white,
        elevation: 5,
      ),
    );
  }
}