import 'package:flutter/material.dart';

import '../data/regions.dart';
import '../models/disability.dart';
import '../models/hospital.dart';
import '../models/search_conditions.dart';
import '../services/recommender.dart';
import 'app_scope.dart';
import 'results_launcher.dart';
import 'retry_message.dart';
import 'search_screen.dart';

/// 병원 찾기에서 묻는 것. 시·군·구는 지역 고르기의 일부라 단계 번호가 같다.
enum FindStep {
  types('어떤 장애가 있으신가요?'),
  severity('장애의 정도를 알려주세요'),
  need('어떤 진료가 필요하신가요?'),
  age('진료받을 분의 나이를 알려주세요'),
  facilities('병원에 꼭 있어야 할 시설을 골라 주세요'),
  region('어디에서 찾을까요?'),
  district('시·군·구를 골라 주세요');

  const FindStep(this.title);
  final String title;

  /// 모두 몇 단계인지 (시·군·구는 지역 고르기에 넣는다).
  static const count = 6;

  /// 화면에 보여 줄 단계 번호 (1부터).
  int get number => this == district ? region.index + 1 : index + 1;
}

/// 장애 유형 → 정도 → 필요한 진료 → 나이 → 편의시설 → 시·도(또는 현재 위치) → 시·군·구 순서로 묻는다.
/// 지난번 조건으로 미리 채우고, 진료 카드에 장애 정보가 있으면 1·2단계는 카드로 채운다.
class FindScreen extends StatefulWidget {
  const FindScreen({super.key});

  @override
  State<FindScreen> createState() => FindScreenState();
}

class FindScreenState extends State<FindScreen> with ResultsLauncher {
  late final AppServices _services = AppScope.of(context);

  /// 지역 고르기 단계에 보여줄 시·도 목록. 못 불러오면 다시 시도로 새로 받는다.
  late Future<List<Region>> _regions = _services.repository.loadRegions();
  final _otherDisability = TextEditingController();
  final _otherNeed = TextEditingController();

  FindStep _step = FindStep.types;
  final Set<DisabilityType> _types = {};
  Severity? _severity;
  CareNeed? _need;
  AgeGroup? _age;

  /// 사용자가 직접 고친 편의시설. null 이면 장애 유형 등으로 정한 [_suggested] 를 쓴다.
  Set<Facility>? _facilities;
  Region? _region;

  /// 시·군·구. 시·도 전체를 고르면 [_region] 자신이 들어간다.
  Area? _area;

  /// 장애 유형·정도를 이번에 직접 골랐는지. 고르기 전이면 진료 카드가 바뀔 때 카드로 다시 채운다.
  bool _disabilityTouched = false;

  @override
  void initState() {
    super.initState();
    _services.careCard.addListener(_cardChanged);
    _services.personalDataCleared.addListener(reset);
    Future.wait([_services.lastSearch.load(), _services.careCard.load()]).then((_) {
      // 그사이 직접 고르기 시작했으면 그대로 둔다. 카드는 먼저 읽혀 채워졌을 수 있다.
      if (!mounted || _disabilityTouched || _step != FindStep.types) return;
      setState(() {
        if (_services.lastSearch.value case final last?) _apply(last);
        _applyCard();
      });
    });
  }

  @override
  void dispose() {
    _services.careCard.removeListener(_cardChanged);
    _services.personalDataCleared.removeListener(reset);
    _otherDisability.dispose();
    _otherNeed.dispose();
    super.dispose();
  }

  void _cardChanged() {
    if (mounted) setState(_applyCard);
  }

  /// 진료 카드에 장애 정보가 있으면 1·2단계를 카드로 채운다. 이번에 직접 고쳤으면 그대로 둔다.
  void _applyCard() {
    final card = _services.careCard.card;
    if (_disabilityTouched || card == null || !card.hasDisability) return;
    _types
      ..clear()
      ..addAll(card.types);
    _otherDisability.text = card.otherDisability;
    if (card.severity != null) _severity = card.severity;
  }

  /// 진료 카드의 장애 정보로 채워 둔 상태인지.
  bool get _filledFromCard {
    final card = _services.careCard.card;
    return !_disabilityTouched &&
        card != null &&
        card.hasDisability &&
        _types.length == card.types.length &&
        _types.containsAll(card.types);
  }

  /// [c] 의 조건을 고른 것으로 채운다.
  void _apply(SearchConditions c) {
    _types
      ..clear()
      ..addAll(c.types);
    _otherDisability.text = c.otherDisability;
    _severity = c.severity;
    _need = c.need;
    _otherNeed.text = c.otherNeed;
    _age = c.age;
    _facilities = c.facilities == null ? null : {...c.facilities!};
    _region = null;
    _area = null;
    if (c.regionCode case final code?) _selectRegion(code, c.districtName);
  }

  /// 지역 목록을 읽은 뒤 [code] 시·도와 [district] 를 고른다.
  Future<void> _selectRegion(String code, String? district) async {
    try {
      final region = (await _regions).where((r) => r.code == code).firstOrNull;
      if (!mounted || region == null || _region != null) return;
      setState(() {
        _region = region;
        _area = district == null
            ? region
            : region.districts.where((d) => d.name == district).firstOrNull;
      });
    } catch (_) {
      // 지역 고르기 단계에서 다시 시도할 수 있다.
    }
  }

  /// 결과 화면에서 조건을 바꾸러 왔을 때: [c] 로 채우고 [step] 단계를 연다.
  void edit(SearchConditions c, FindStep step) => setState(() {
        _apply(c);
        _disabilityTouched = true;
        _step = step;
      });

  /// 내 정보를 지운 뒤 고른 것을 모두 비운다.
  void reset() => setState(() {
        _types.clear();
        _otherDisability.clear();
        _severity = null;
        _need = null;
        _otherNeed.clear();
        _age = null;
        _facilities = null;
        _region = null;
        _area = null;
        _disabilityTouched = false;
        _step = FindStep.types;
      });

  /// 이전 단계로 간다. 첫 단계면 false.
  bool back() {
    if (_step == FindStep.types) return false;
    setState(() => _step = FindStep.values[_step.index - 1]);
    return true;
  }

  Set<Facility> get _suggested => suggestedFacilities(
      _types, _severity ?? Severity.mild, _need ?? CareNeed.general);

  bool get _canProceed => switch (_step) {
        FindStep.types => _types.isNotEmpty &&
            (!_types.contains(DisabilityType.other) ||
                _otherDisability.text.trim().isNotEmpty),
        FindStep.severity => _severity != null,
        FindStep.need => _need != null &&
            (_need != CareNeed.other || _otherNeed.text.trim().isNotEmpty),
        FindStep.age => _age != null,
        FindStep.facilities => true,
        FindStep.region => _region != null,
        FindStep.district => _area != null,
      };

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step != FindStep.district) {
      setState(() => _step = FindStep.values[_step.index + 1]);
      return;
    }
    showResults(_conditions(
      region: _region,
      district: identical(_area, _region) ? null : _area,
    ));
  }

  /// 지금까지 고른 조건. [region] 이 없으면 현재 위치로 찾는다.
  SearchConditions _conditions({Region? region, Area? district}) => SearchConditions(
        types: Set.of(_types),
        otherDisability:
            _types.contains(DisabilityType.other) ? _otherDisability.text.trim() : '',
        severity: _severity!,
        need: _need!,
        otherNeed: _need == CareNeed.other ? _otherNeed.text.trim() : '',
        age: _age,
        facilities: _facilities == null ? null : Set.of(_facilities!),
        regionCode: region?.code,
        regionName: region?.name ?? '',
        districtName: district?.name,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tall = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('병원 찾기'),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_search),
            tooltip: '병원 이름으로 찾기',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: LinearProgressIndicator(value: _step.number / FindStep.count),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('${_step.number} / ${FindStep.count} 단계',
                  style: theme.textTheme.labelLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Semantics(
                header: true,
                child: Text(_step.title, style: theme.textTheme.headlineSmall),
              ),
            ),
            Expanded(child: _buildStep()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_step != FindStep.types) ...[
                    Expanded(
                      child: OutlinedButton(style: tall, onPressed: back, child: const Text('이전')),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: tall,
                      onPressed: _canProceed ? _next : null,
                      child: Text(_step == FindStep.district ? '추천 병원 보기' : '다음'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// '기타'를 골랐을 때 나타나는 직접 입력 칸.
  Widget _otherField(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 30,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: '직접 입력',
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _canProceed ? _next() : null,
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Text(text),
      );

  Widget _buildStep() {
    return switch (_step) {
      FindStep.types => ListView(
          children: [
            _note(_filledFromCard
                ? '나의 진료 카드에 적은 장애로 미리 골라 두었어요. 여러 개를 고를 수 있어요.'
                : '여러 개를 고를 수 있어요.'),
            for (final t in DisabilityType.values) ...[
              CheckboxListTile(
                title: Text(t.label),
                value: _types.contains(t),
                onChanged: (on) => setState(() {
                  _disabilityTouched = true;
                  on! ? _types.add(t) : _types.remove(t);
                }),
              ),
              if (t == DisabilityType.other && _types.contains(t))
                _otherField(_otherDisability, '예: 척수장애, 희귀질환'),
            ],
          ],
        ),
      FindStep.severity => RadioGroup<Severity>(
          groupValue: _severity,
          onChanged: (v) => setState(() {
            _disabilityTouched = true;
            _severity = v;
          }),
          child: ListView(
            children: [
              for (final s in Severity.values)
                RadioListTile<Severity>(
                  value: s,
                  title: Text(s.label),
                  subtitle: Text(s.hint),
                ),
              _note('2019년 7월부터 1~6급 장애등급 대신 이 두 가지로 구분해요.'),
            ],
          ),
        ),
      FindStep.need => RadioGroup<CareNeed>(
          groupValue: _need,
          onChanged: (v) => setState(() => _need = v),
          child: ListView(
            children: [
              for (final n in CareNeed.values) ...[
                RadioListTile<CareNeed>(
                  value: n,
                  title: Text(n.label),
                  subtitle: Text(n.hint),
                ),
                if (n == CareNeed.other && _need == n)
                  _otherField(_otherNeed, '예: 허리 통증, 피부 질환'),
              ],
            ],
          ),
        ),
      FindStep.age => RadioGroup<AgeGroup>(
          groupValue: _age,
          onChanged: (v) => setState(() => _age = v),
          child: ListView(
            children: [
              for (final a in AgeGroup.values)
                RadioListTile<AgeGroup>(
                  value: a,
                  title: Text(a.label),
                  subtitle: Text(a.hint),
                ),
              _note('어린이·청소년이면 소아청소년과와 공공어린이재활병원을 먼저 보여 줘요.'),
            ],
          ),
        ),
      FindStep.facilities => _facilityStep(),
      FindStep.region => _regionStep(),
      FindStep.district => RadioGroup<Area>(
          groupValue: _area,
          onChanged: (v) => setState(() => _area = v),
          child: ListView(
            children: [
              RadioListTile<Area>(
                value: _region!,
                title: Text('${_region!.name} 전체'),
              ),
              for (final d in _region!.districts)
                RadioListTile<Area>(value: d, title: Text(d.name)),
            ],
          ),
        ),
    };
  }

  Widget _facilityStep() {
    final shown = _facilities ?? _suggested;
    return ListView(
      children: [
        _note(_facilities == null
            ? '고르신 장애와 진료에 맞춰 미리 골라 두었어요. 더하거나 뺄 수 있고, 그냥 넘어가도 돼요.'
            : '직접 고른 시설이 있는 병원을 더 먼저 보여 줘요.'),
        for (final f in Facility.values)
          CheckboxListTile(
            title: Text(f.label),
            value: shown.contains(f),
            onChanged: (on) => setState(() {
              _facilities = {...shown};
              on! ? _facilities!.add(f) : _facilities!.remove(f);
            }),
          ),
        if (_facilities != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => setState(() => _facilities = null),
                child: const Text('처음 골라 둔 대로 되돌리기'),
              ),
            ),
          ),
        _note('편의시설 정보가 아직 없는 병원이 많아요. 정보가 없는 병원은 순서를 낮추지 않고 '
            '‘정보 없음’으로 알려 드려요.'),
      ],
    );
  }

  Widget _regionStep() {
    return FutureBuilder(
      future: _regions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return RetryMessage(
            message: '지역 정보를 불러오지 못했어요.',
            // setState 안에서 Future 를 돌려주면 안 되므로 블록으로 쓴다.
            onRetry: () => setState(() {
              _regions = _services.repository.loadRegions();
            }),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final regions = snapshot.data!;
        return RadioGroup<Region>(
          groupValue: _region,
          onChanged: (v) => setState(() {
            if (v != _region) _area = null;
            _region = v;
          }),
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: locating
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(locating ? '현재 위치를 확인하고 있어요' : '현재 위치로 찾기'),
                  onPressed: locating ? null : () => showResults(_conditions()),
                ),
              ),
              _note('또는 지역을 직접 고르세요'),
              for (final r in regions) RadioListTile<Region>(value: r, title: Text(r.name)),
            ],
          ),
        );
      },
    );
  }
}
