import 'package:flutter/material.dart';

class RecommendationFAB extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const RecommendationFAB({
    Key? key,
    required this.isLoading,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: isLoading ? null : onPressed,
      label: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text('AIviser'),
      icon: isLoading ? null : const Icon(Icons.arrow_upward),
      tooltip: 'Show AI Recommendation',
      backgroundColor: Theme.of(context).colorScheme.secondary,
    );
  }
}