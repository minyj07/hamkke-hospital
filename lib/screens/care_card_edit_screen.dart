import 'package:flutter/material.dart';

import '../models/care_card.dart';
import '../models/disability.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';

/// 진료 카드 만들기·고치기. 모든 칸은 비워 둘 수 있다.
class CareCardEditScreen extends StatefulWidget {
  const CareCardEditScreen({super.key});

  @override
  State<CareCardEditScreen> createState() => _CareCardEditScreenState();
}

class _CareCardEditScreenState extends State<CareCardEditScreen> {
  late final AppServices _services = AppScope.of(context);
  late final CareCard _initial = _services.careCard.card ?? const CareCard();
  late final bool _isNew = _services.careCard.card == null;

  late final _name = TextEditingController(text: _initial.name);
  late final _otherDisability = TextEditingController(text: _initial.otherDisability);
  late final _otherCommunication = TextEditingController(text: _initial.otherCommunication);
  late final _otherHelp = TextEditingController(text: _initial.otherHelp);
  late final _cautions = TextEditingController(text: _initial.cautions);
  late final _conditions = TextEditingController(text: _initial.conditions);
  late final _allergies = TextEditingController(text: _initial.allergies);
  late final _guardianName = TextEditingController(text: _initial.guardianName);
  late final _guardianPhone = TextEditingController(text: _initial.guardianPhone);
  late final _types = {..._initial.types};
  late Severity? _severity = _initial.severity;
  late final _communication = {..._initial.communication};
  late final _help = {..._initial.help};

  /// 저장하지 않은 고친 내용이 있는지.
  bool _dirty = false;

  List<TextEditingController> get _controllers => [
        _name,
        _otherDisability,
        _otherCommunication,
        _otherHelp,
        _cautions,
        _conditions,
        _allergies,
        _guardianName,
        _guardianPhone,
      ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed([VoidCallback? apply]) => setState(() {
        apply?.call();
        _dirty = true;
      });

  CareCard get _card => CareCard(
        name: _name.text.trim(),
        types: Set.of(_types),
        otherDisability:
            _types.contains(DisabilityType.other) ? _otherDisability.text.trim() : '',
        severity: _severity,
        communication: Set.of(_communication),
        otherCommunication: _otherCommunication.text.trim(),
        help: Set.of(_help),
        otherHelp: _otherHelp.text.trim(),
        cautions: _cautions.text.trim(),
        conditions: _conditions.text.trim(),
        allergies: _allergies.text.trim(),
        guardianName: _guardianName.text.trim(),
        guardianPhone: _guardianPhone.text.trim(),
      );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _services.careCard.save(_card);
    setState(() => _dirty = false);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('진료 카드를 저장했어요.')));
  }

  Future<bool> _confirm(String title, String message, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(yes),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _delete() async {
    if (!await _confirm('진료 카드를 지울까요?', '지우면 되돌릴 수 없어요.', '지우기')) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _services.careCard.clear();
    setState(() => _dirty = false);
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('진료 카드를 지웠어요.')));
  }

  /// 섹션 제목(디자인: 17/800)과 설명(13, 회색). 섹션 사이는 30, 제목과 내용 사이는 12.
  Widget _heading(String text, [String? note]) {
    final c = MediumColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 30, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (note != null) ...[
            const SizedBox(height: 6),
            Text(note, style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary)),
          ],
        ],
      ),
    );
  }

  /// 입력 칸 (디자인: 둥근 14, 높이 56, 여러 줄은 3줄). 라벨 글은 화면낭독기와 테스트가 찾는다.
  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int lines = 1,
    TextInputType? keyboard,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: TextField(
          controller: controller,
          minLines: lines,
          maxLines: lines == 1 ? 1 : lines + 3,
          maxLength: lines == 1 ? 40 : 300,
          keyboardType: keyboard ?? (lines == 1 ? TextInputType.text : TextInputType.multiline),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.5, color: MediumColors.of(context).text),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            alignLabelWithHint: lines > 1,
          ),
          onChanged: (_) => _dirty ? null : _changed(),
        ),
      );

  /// 고르는 칩 (디자인: 높이 40, 둥근 12, 고르면 연한 초록 바탕·초록 테두리·체크).
  Widget _chips<T>(List<T> values, Set<T> selected, String Function(T) label) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            FilterChip(
              label: Text(label(v)),
              selected: selected.contains(v),
              onSelected: (on) => _changed(() => on ? selected.add(v) : selected.remove(v)),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirm('저장하지 않고 나갈까요?', '고친 내용이 사라져요.', '나가기')) {
          setState(() => _dirty = false);
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '진료 카드 만들기' : '진료 카드 고치기'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: c.link),
              onPressed: _save,
              child: const Text('저장'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '모든 칸은 비워 둬도 돼요. 이 휴대폰의 보안 저장소에만 암호화해서 저장해요.',
              style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            _field(_name, '이름 또는 불러 주었으면 하는 이름', hint: '예: 김함께'),
            _heading('장애', '병원 찾기에서도 이 장애 유형과 정도를 미리 골라 둬요.'),
            _chips(DisabilityType.values, _types, (t) => t.label),
            if (_types.contains(DisabilityType.other)) ...[
              const SizedBox(height: 12),
              _field(_otherDisability, '기타 장애', hint: '예: 척수장애'),
            ],
            const SizedBox(height: 8),
            for (final (value, label) in [
              for (final s in Severity.values) (s, s.label),
              (null, '적지 않을래요'),
            ])
              OptionTile(
                label: label,
                selected: _severity == value,
                style: OptionStyle.radio,
                leadingIndicator: true,
                divider: false,
                onTap: () => _changed(() => _severity = value),
              ),
            _heading('소통 방법', '의료진에게 바라는 방법을 모두 고르세요.'),
            _chips(Communication.values, _communication, (c) => c.label),
            const SizedBox(height: 12),
            _field(_otherCommunication, '그 밖의 소통 방법', hint: '예: 그림으로 설명해 주세요.'),
            _heading('필요한 도움'),
            _chips(HelpNeed.values, _help, (h) => h.label),
            const SizedBox(height: 12),
            _field(_otherHelp, '그 밖에 필요한 도움', hint: '예: 엘리베이터까지 안내해 주세요.'),
            _heading('주의할 점'),
            _field(_cautions, '주의할 점', hint: '예: 큰 소리에 놀라요. 주사를 무서워해요.', lines: 3),
            _heading('앓고 있는 병·먹는 약'),
            _field(_conditions, '앓고 있는 병·먹는 약', hint: '예: 고혈압, 혈압약 하루 1번', lines: 3),
            _heading('알레르기'),
            _field(_allergies, '알레르기', hint: '예: 페니실린'),
            _heading('보호자 연락처'),
            _field(_guardianName, '보호자 이름이나 관계', hint: '예: 엄마'),
            const SizedBox(height: 6),
            _field(_guardianPhone, '보호자 전화번호',
                hint: '예: 010-1234-5678', keyboard: TextInputType.phone),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _save,
              child: const Text('저장하기'),
            ),
            if (!_isNew) ...[
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: c.warning,
                ),
                onPressed: _delete,
                child: const Text('진료 카드 지우기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
