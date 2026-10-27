import 'package:flutter/material.dart';

import '../data/regions.dart';

/// 병원 정보를 보여 주는 화면마다 붙이는 안내.
const dataNotice = '공공데이터 기준이라 실제와 다를 수 있어요. 방문 전 전화로 확인하세요.';

/// [dataNotice] 와, [info] 가 있으면 데이터 기준일·출처.
class DataNotice extends StatelessWidget {
  const DataNotice({super.key, this.info, this.emergency = false});

  final DataInfo? info;

  /// 응급 상황이면 119 에 전화하라는 안내도 붙인다.
  final bool emergency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                dataNotice,
                if (emergency) '응급 상황이면 119에 전화하세요.',
                if (info case final info?)
                  '\n${info.generatedAt} 기준 공공데이터 · 자료: ${info.sources.join(', ')}',
              ].join(' '),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
