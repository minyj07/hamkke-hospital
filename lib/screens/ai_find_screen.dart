import 'package:flutter/material.dart';

import '../ai/intent_model.dart';
import '../ai/place_finder.dart';
import '../models/disability.dart';
import '../models/hospital.dart';
import '../models/search_conditions.dart';
import '../services/recommender.dart' show suggestedFacilities;
import '../ui/icons.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'find_screen.dart';
import 'results_launcher.dart';

/// 화면에 넣어 둔 예시. 누르면 글 칸을 채우고 바로 알아본다.
const aiExamples = [
  '휠체어 타시는 아버지가 당뇨 때문에 꾸준히 다닐 병원, 수원',
  '7살 아들이 자폐가 있는데 치과 치료를 받아야 해요',
  '청각장애가 심해서 수어 통역 되는 내과를 찾아요 강남',
];

/// AI로 말해서 찾기: 상황을 말하듯 적으면(키보드의 음성 입력도 된다) 휴대폰 안의 AI 가 병원 찾기 조건을 알아낸다.
///
/// 장애 유형·정도·진료·나이·편의시설은 AI 모델([IntentModel])이, 지역은 지역 이름표([PlaceFinder])가 찾는다.
/// 알아낸 것을 보여 주고 글에 없는 장애 정도만 한 번 더 물은 뒤 찾는다. 맞지 않으면 병원 찾기 단계에서 고친다.
/// 쓰는 중인 글은 엉뚱하게 알아들을 수 있어서 글자마다 알아보지 않고, 'AI로 조건 알아보기'를 누를 때 알아본다.
/// 적은 글은 기기 밖으로 보내지 않고 저장하지 않는다. 찾으면 알아낸 조건만 지난번 검색 조건으로 저장된다.
class AiFindScreen extends StatefulWidget {
  const AiFindScreen({super.key});

  @override
  State<AiFindScreen> createState() => _AiFindScreenState();
}

/// AI 가 알아낸 것에 사용자가 더 고른 장애 정도를 합친 조건.
class _Understood {
  _Understood(this.result, this.place);

  final IntentResult result;
  final PlaceMatch? place;

  /// 글에 장애 정도가 없어서 사용자가 고른 것.
  Severity? chosenSeverity;

  Set<DisabilityType> get types => result.types;
  Severity? get severity => result.severity ?? chosenSeverity;

  /// 글에 진료가 없으면(또는 '기타'인데 진료과를 모르면) 일반 진료로 찾는다.
  bool get needGuessed =>
      result.need == null || (result.need == CareNeed.other && result.departments.isEmpty);
  CareNeed get need => needGuessed ? CareNeed.general : result.need!;

  /// '기타' 진료는 알아낸 진료과 이름을 적은 것으로 본다 (추천이 그 글에서 진료과를 찾는다).
  String get otherNeed => need == CareNeed.other ? result.departments.join(', ') : '';
  AgeGroup get age => result.child ? AgeGroup.child : AgeGroup.adult;

  Set<Facility> get _suggested => suggestedFacilities(types, severity ?? Severity.mild, need);

  /// 글에 적은 시설이 있으면 장애에 맞춰 고르는 시설과 함께 직접 고른 것으로 본다. 없으면 null 이라 앱이 고른다.
  Set<Facility>? get facilities =>
      result.facilities.isEmpty ? null : {..._suggested, ...result.facilities};
  Set<Facility> get shownFacilities => facilities ?? _suggested;

  bool get ready => types.isNotEmpty && severity != null;

  SearchDraft get draft => SearchDraft(
        types: types,
        severity: severity,
        need: need,
        otherNeed: otherNeed,
        age: age,
        facilities: facilities,
        regionCode: place?.region.code,
        districtName: place?.district?.name,
      );

  SearchConditions get conditions => SearchConditions(
        types: types,
        severity: severity!,
        need: need,
        otherNeed: otherNeed,
        age: age,
        facilities: facilities,
        regionCode: place?.region.code,
        regionName: place?.region.name ?? '',
        districtName: place?.district?.name,
      );
}

class _AiFindScreenState extends State<AiFindScreen> with ResultsLauncher {
  late final AppServices _services = AppScope.of(context);
  final _text = TextEditingController();
  final _resultKey = GlobalKey();

  IntentModel? _model;
  bool _modelFailed = false;
  PlaceFinder? _places;
  _Understood? _understood;

  @override
  void initState() {
    super.initState();
    _services.personalDataCleared.addListener(_clear);
    _loadModel();
    _services.repository.loadRegions().then((regions) {
      if (!mounted) return;
      final places = PlaceFinder(regions);
      setState(() {
        _places = places;
        // 지역보다 먼저 알아봤으면 지역만 다시 찾는다.
        if (_understood case final u?) {
          _understood = _Understood(u.result, places.find(_text.text))
            ..chosenSeverity = u.chosenSeverity;
        }
      });
    }, onError: (Object _) {
      // 지역 정보를 못 읽으면 글의 지역은 찾지 않고 현재 위치로 찾는다.
    });
  }

  @override
  void dispose() {
    _services.personalDataCleared.removeListener(_clear);
    _text.dispose();
    super.dispose();
  }

  void _loadModel() {
    _services.intent.load().then((model) {
      if (mounted) setState(() => _model = model);
    }, onError: (Object _) {
      if (mounted) setState(() => _modelFailed = true);
    });
  }

  void _retryModel() {
    setState(() => _modelFailed = false);
    _loadModel();
  }

  /// 내 정보를 지우면 적은 글과 알아낸 것도 지운다.
  void _clear() => setState(() {
        _text.clear();
        _understood = null;
      });

  /// 글을 고치면 알아낸 것을 지운다. 고친 글로 다시 알아본다.
  void _onChanged(String _) => setState(() => _understood = null);

  void _understand() {
    final model = _model;
    final text = _text.text.trim();
    if (model == null || text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _understood = _Understood(model.understand(text), _places?.find(text)));
    // 알아낸 것이 보이게 굴린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final result = _resultKey.currentContext;
      if (result != null && result.mounted) {
        Scrollable.ensureVisible(result, duration: const Duration(milliseconds: 300), alignment: 0.05);
      }
    });
  }

  void _useExample(String example) {
    _text.text = example;
    _understand();
  }

  void _search() {
    final u = _understood;
    if (u != null && u.ready) showResults(u.conditions);
  }

  /// 알아낸 조건으로 병원 찾기를 채워 연다. 모르는 단계가 있으면 그 단계를, 아니면 처음부터 확인하게 연다.
  void _edit() {
    final u = _understood;
    if (u == null) return;
    FocusScope.of(context).unfocus();
    final step = u.types.isNotEmpty && u.severity == null ? FindStep.severity : FindStep.types;
    AppShell.of(context).prefillSearch(u.draft, step);
  }

  void _onBack() {
    FocusScope.of(context).unfocus();
    AppShell.of(context).showTab(AppTab.home);
  }

  void _showAbout() {
    final trained = _model?.trained ?? '';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI는 어떻게 알아듣나요?'),
        content: SingleChildScrollView(
          child: Text(
            '메디움 안에 든 작은 AI(신경망)가 이 휴대폰에서만 글을 읽어요. 인터넷이 없어도 되고, '
            '적은 글은 어디로 보내거나 저장하지 않아요.\n\n'
            '글을 낱말과 글자 조각으로 나눠 장애 유형, 장애 정도, 필요한 진료, 나이, 편의시설을 한 번에 알아내요. '
            '지역은 시·군·구 이름표에서 찾아요.\n\n'
            '사람들이 장애와 진료를 말하는 여러 방식을 모아 만든 문장 3만 개로 학습했어요'
            '${trained.isEmpty ? '' : ' ($trained)'}.\n\n'
            'AI는 틀릴 수 있어요. 찾기 전에 알아낸 조건이 맞는지 꼭 확인해 주세요.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기')),
        ],
      ),
    );
  }

  /// 아래 큰 버튼: 알아보기 → (장애를 모르면) 단계별로 고르기 → 이 조건으로 찾기.
  (String, VoidCallback?) get _primary {
    final u = _understood;
    if (u == null) {
      if (_model == null && !_modelFailed) return ('AI를 준비하고 있어요', null);
      final canAsk = _model != null && _text.text.trim().isNotEmpty;
      return ('AI로 조건 알아보기', canAsk ? _understand : null);
    }
    if (u.types.isEmpty) return ('단계별로 골라서 찾기', _edit);
    if (locating) return ('현재 위치를 확인하고 있어요', null);
    return ('이 조건으로 병원 찾기', u.ready ? _search : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    final small = TextStyle(fontSize: 14, height: 1.45, color: c.textSecondary);
    final u = _understood;
    final (label, onPressed) = _primary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '홈으로',
          icon: const DesignIcon(DesignIcons.back, size: 22, strokeWidth: 2.2),
          onPressed: _onBack,
        ),
        title: const Text('AI로 말해서 찾기'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              children: [
                Semantics(
                  header: true,
                  child: Text('어떤 병원을 찾으세요?', style: theme.textTheme.headlineSmall),
                ),
                const SizedBox(height: 8),
                Text(
                  '누가, 어떤 장애가 있고, 어떤 진료가 필요한지 편하게 적어 주세요. '
                  '키보드의 마이크를 눌러 말해도 돼요.',
                  style: small,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 200,
                  // 여러 줄로 보여 주되, 키보드의 완료 버튼은 줄을 바꾸지 않고 알아보기를 한다.
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _understand(),
                  decoration: InputDecoration(
                    labelText: '상황을 적어 주세요',
                    hintText: '예: 휠체어 타시는 아버지가 당뇨 때문에 꾸준히 다닐 병원',
                    alignLabelWithHint: true,
                    suffixIcon: _text.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '글 지우기',
                            icon: DesignIcon(DesignIcons.close, size: 18, strokeWidth: 2.4, color: c.textSecondary),
                            onPressed: () {
                              _text.clear();
                              _onChanged('');
                            },
                          ),
                  ),
                ),
                if (_modelFailed)
                  Row(children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text('AI를 불러오지 못했어요.', style: small.copyWith(color: c.warning)),
                      ),
                    ),
                    TextButton(onPressed: _retryModel, child: const Text('다시 시도')),
                  ]),
                if (u != null) ...[
                  const SizedBox(height: 8),
                  _UnderstoodCard(
                    key: _resultKey,
                    understood: u,
                    onSeverity: (s) => setState(() => u.chosenSeverity = s),
                    onEdit: _edit,
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  Text('이렇게 적어 보세요', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  for (final example in aiExamples) ...[
                    _ExampleTile(
                      example,
                      onTap: _model == null ? null : () => _useExample(example),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: DesignIcon(DesignIcons.lock, size: 18, color: c.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('적은 글은 이 휴대폰 안의 AI만 읽어요. 인터넷으로 보내거나 저장하지 않아요.', style: small),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: _showAbout, child: const Text('AI는 어떻게 알아듣나요?')),
                ),
              ],
            ),
          ),
          BottomActionArea(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: onPressed,
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

/// 'AI가 이렇게 이해했어요' 상자. 글에 장애 정도가 없으면 여기서 고르게 한다.
class _UnderstoodCard extends StatelessWidget {
  const _UnderstoodCard({
    super.key,
    required this.understood,
    required this.onSeverity,
    required this.onEdit,
  });

  final _Understood understood;
  final ValueChanged<Severity> onSeverity;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final u = understood;
    final status = u.types.isEmpty
        ? '장애를 알아듣지 못했어요. 어떤 장애나 불편이 있는지 더 적어 주시거나 단계별로 골라 주세요.'
        : u.severity == null
            ? '장애의 정도만 골라 주시면 바로 찾을 수 있어요.'
            : '맞는지 확인하고 찾아 주세요. 틀린 곳은 고쳐서 찾을 수 있어요.';
    final facilities = u.shownFacilities;
    return SectionBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('AI가 이렇게 이해했어요', icon: DesignIcons.sparkle),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(status, style: TextStyle(fontSize: 14, height: 1.45, color: c.textSecondary)),
          ),
          const SizedBox(height: 6),
          _Fact('장애', u.types.isEmpty ? '알아듣지 못했어요' : disabilityLabel(u.types, ''), missing: u.types.isEmpty),
          if (u.types.isNotEmpty)
            if (u.result.severity case final severity?)
              _Fact('장애 정도', severity.label)
            else
              _SeverityChoice(selected: u.chosenSeverity, onSelected: onSeverity),
          _Fact(
            '필요한 진료',
            careNeedLabel(u.need, u.otherNeed),
            note: u.needGuessed ? '글에 없어서 일반 진료로 찾아요' : null,
          ),
          _Fact('나이', u.age.label),
          _Fact(
            '꼭 있어야 할 시설',
            facilities.isEmpty ? '따로 없어요' : [for (final f in facilities) f.label].join(', '),
            note: u.result.facilities.isEmpty && facilities.isNotEmpty ? '장애와 진료에 맞춰 골랐어요' : null,
          ),
          _Fact(
            '지역',
            u.place?.label ?? '현재 위치',
            note: u.place == null ? '글에 지역이 없어서, 찾을 때 지금 있는 곳을 확인해요' : null,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onEdit, child: const Text('조건 고쳐서 찾기')),
          ),
        ],
      ),
    );
  }
}

/// 알아낸 조건 한 줄: 작은 이름 아래에 값. 화면낭독기는 '장애, 지체장애'처럼 한 번에 읽는다.
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value, {this.note, this.missing = false});

  final String label;
  final String value;

  /// 값 아래의 작은 설명 (예: 글에 없어서 정한 것).
  final String? note;

  /// 알아듣지 못한 것.
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: missing ? c.warning : c.text,
              ),
            ),
            if (note != null)
              Text(note!, style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// 글에 장애 정도가 없을 때 고르는 두 줄.
class _SeverityChoice extends StatelessWidget {
  const _SeverityChoice({required this.selected, required this.onSelected});

  final Severity? selected;
  final ValueChanged<Severity> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('장애 정도', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
          Text('글에 없어서 여쭤봐요. 하나를 골라 주세요.', style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary)),
          for (final s in Severity.values)
            OptionTile(
              label: s.label,
              hint: s.hint,
              style: OptionStyle.single,
              selected: selected == s,
              onTap: () => onSelected(s),
            ),
        ],
      ),
    );
  }
}

/// 예시 문장 한 줄. 누르면 글 칸에 넣고 알아본다.
class _ExampleTile extends StatelessWidget {
  const _ExampleTile(this.text, {required this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '예시 넣기: $text',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.container,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  DesignIcon(DesignIcons.talk, size: 18, color: c.brandDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(text, style: TextStyle(fontSize: 14, height: 1.45, color: c.text)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
