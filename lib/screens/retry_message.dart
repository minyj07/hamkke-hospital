import 'package:flutter/material.dart';

/// 데이터를 불러오지 못했을 때의 안내와 다시 시도 버튼.
class RetryMessage extends StatelessWidget {
  const RetryMessage({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 화면 읽기 프로그램이 바로 읽어 주게 한다.
            Semantics(
              liveRegion: true,
              child: Text(message, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(200, 56)),
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
