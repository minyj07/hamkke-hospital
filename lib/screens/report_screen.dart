import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hospital.dart';
import 'app_scope.dart';

/// 틀린 정보 종류.
enum ReportItem {
  phone('전화번호'),
  address('주소'),
  facilities('편의시설'),
  designation('지정 현황'),
  closed('문을 닫았어요 (폐업)'),
  other('그 밖의 정보');

  const ReportItem(this.label);
  final String label;
}

/// 신고 메일 본문. 병원 ID 와 앱·데이터 버전을 붙이고, 장애·위치 같은 개인 정보는 넣지 않는다.
String reportBody(
  Hospital h,
  Set<ReportItem> items,
  String memo, {
  required String appVersion,
  required String dataVersion,
}) =>
    [
      '병원: ${h.name}',
      '주소: ${h.address}',
      '병원 ID: ${h.id} (시·도 ${h.region})',
      if (items.isNotEmpty)
        '틀린 정보: ${[
          for (final i in ReportItem.values)
            if (items.contains(i)) i.label,
        ].join(', ')}',
      if (memo.trim().isNotEmpty) '자세한 내용: ${memo.trim()}',
      '',
      '앱 버전: $appVersion',
      '데이터 기준일: $dataVersion',
    ].join('\n');

/// 로그인·서버 없이 휴대폰의 메일 앱으로 보낸다. 운영자가 확인한 뒤 다음 데이터 갱신 때 고친다.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.hospital});

  final Hospital hospital;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _items = <ReportItem>{};
  final _memo = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  bool get _ready => _items.isNotEmpty || _memo.text.trim().isNotEmpty;

  Future<void> _send() async {
    final services = AppScope.of(context);
    setState(() => _sending = true);
    var dataVersion = '알 수 없음';
    try {
      dataVersion = (await services.repository.loadInfo()).generatedAt;
    } catch (_) {
      // 기준일 없이 보낸다.
    }
    final h = widget.hospital;
    final body = reportBody(h, _items, _memo.text,
        appVersion: services.appVersion, dataVersion: dataVersion);
    final mail = Uri.parse('mailto:${services.contactEmail}'
        '?subject=${Uri.encodeComponent('[함께병원 정보 오류] ${h.name}')}'
        '&body=${Uri.encodeComponent(body)}');
    var opened = false;
    try {
      opened = await launchUrl(mail, mode: LaunchMode.externalApplication);
    } on PlatformException {
      // 아래에서 안내한다.
    }
    if (!mounted) return;
    setState(() => _sending = false);
    if (opened) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('메일 앱에서 보내 주시면 확인해서 다음 데이터 갱신 때 고칠게요.'),
      ));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('메일 앱을 열 수 없어요'),
        content: Text('아래 주소로 내용을 보내 주세요.\n${services.contactEmail}'),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '${services.contactEmail}\n\n$body'));
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('주소와 내용 복사'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('정보가 틀렸어요')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.hospital.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('어떤 정보가 틀렸나요? 고른 내용으로 메일을 만들어요. '
              '보내기 전에 메일 앱에서 내용을 확인할 수 있어요.'),
          const SizedBox(height: 8),
          for (final item in ReportItem.values)
            CheckboxListTile(
              title: Text(item.label),
              value: _items.contains(item),
              onChanged: (on) => setState(() => on! ? _items.add(item) : _items.remove(item)),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _memo,
            maxLength: 300,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: '자세한 내용 (안 써도 돼요)',
              hintText: '예: 전화번호가 02-123-4567로 바뀌었어요',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          Text(
            '이름·장애 정보·위치 같은 개인 정보는 넣지 않아요. 병원 정보와 앱 버전만 함께 보내요.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.mail_outline),
            label: Text(_sending ? '메일 앱을 여는 중이에요' : '메일로 보내기'),
            onPressed: _ready && !_sending ? _send : null,
          ),
        ],
      ),
    );
  }
}
