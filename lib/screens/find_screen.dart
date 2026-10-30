import 'package:flutter/material.dart';

import '../data/regions.dart';
import '../models/disability.dart';
import '../models/hospital.dart';
import '../models/search_conditions.dart';
import '../services/recommender.dart';
import '../ui/icons.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'results_launcher.dart';
import 'retry_message.dart';

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
///
/// 모양은 메디움 디자인: 뒤로 화살표와 '병원 찾기', 진행 막대, 'N / 6 단계'와 제목·설명, 고르는 줄,
/// 아래에 붙은 큰 버튼. 이전 단계로는 앱 바의 뒤로 화살표(와 휴대폰의 뒤로 가기)로 간다.
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

  /// 'AI로 말해서 찾기'에서 알아낸 조건으로 채웠는지. 첫 단계 설명에 알린다.
  bool _filledByAi = false;

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
  void _apply(SearchConditions c) => _fill(c.toDraft());

  /// [d] 의 조건을 고른 것으로 채운다. 모르는 것은 비워 둔다.
  void _fill(SearchDraft d) {
    _types
      ..clear()
      ..addAll(d.types);
    _otherDisability.text = d.otherDisability;
    _severity = d.severity;
    _need = d.need;
    _otherNeed.text = d.otherNeed;
    _age = d.age;
    _facilities = d.facilities == null ? null : {...d.facilities!};
    _region = null;
    _area = null;
    _filledByAi = false;
    if (d.regionCode case final code?) _selectRegion(code, d.districtName);
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

  /// 'AI로 말해서 찾기'에서 고치러 왔을 때: AI 가 알아낸 [d] 로 채우고 [step] 단계를 연다.
  void prefill(SearchDraft d, FindStep step) => setState(() {
        _fill(d);
        _filledByAi = true;
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
        _filledByAi = false;
        _step = FindStep.types;
      });

  /// 이전 단계로 간다. 첫 단계면 false.
  bool back() {
    if (_step == FindStep.types) return false;
    setState(() => _step = FindStep.values[_step.index - 1]);
    return true;
  }

  /// 앱 바의 뒤로 화살표: 이전 단계로 가고, 첫 단계면 홈으로 간다.
  void _onBack() {
    FocusScope.of(context).unfocus();
    if (!back()) AppShell.of(context).showTab(AppTab.home);
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

  /// 제목 아래 설명 (디자인: 14 회색). 없으면 null.
  String? get _description => switch (_step) {
        FindStep.types => _filledByAi
            ? 'AI가 알아들은 조건으로 미리 골라 두었어요. 단계마다 맞는지 확인해 주세요. 여러 개를 고를 수 있어요.'
            : _filledFromCard
                ? '나의 진료 카드에 적은 장애로 미리 골라 두었어요. 여러 개를 고를 수 있어요.'
                : '여러 개를 고를 수 있어요.',
        FindStep.severity => '2019년 7월부터 1~6급 장애등급 대신 이 두 가지로 구분해요.',
        FindStep.need => '하나만 고를 수 있어요.',
        FindStep.age => '어린이·청소년이면 소아청소년과와 공공어린이재활병원을 먼저 보여 줘요.',
        FindStep.facilities => _facilities == null
            ? '고르신 장애와 진료에 맞춰 미리 골라 두었어요. 더하거나 뺄 수 있고, 그냥 넘어가도 돼요.'
            : '직접 고른 시설이 있는 병원을 더 먼저 보여 줘요.',
        FindStep.region || FindStep.district => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    final description = _description;
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_step.number} / ${FindStep.count} 단계',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.link),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(_step.title, style: theme.textTheme.headlineSmall),
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description, style: TextStyle(fontSize: 14, height: 1.45, color: c.textSecondary)),
          ],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _step == FindStep.types ? '홈으로' : '이전 단계',
          icon: const DesignIcon(DesignIcons.back, size: 22, strokeWidth: 2.2),
          onPressed: _onBack,
        ),
        title: const Text('병원 찾기'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(13),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: StepProgressBar(value: _step.number / FindStep.count),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildStep(header)),
          // 목록 위에 겹치지 않고 아래에 따로 둔다. 겹치면 맨 아래 줄을 누를 때 버튼이 눌릴 수 있다.
          BottomActionArea(
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _canProceed ? _next : null,
              child: Text(_step == FindStep.district ? '추천 병원 보기' : '다음'),
            ),
          ),
        ],
      ),
    );
  }

  /// 제목과 고르는 줄을 한 목록으로 굴린다 (디자인처럼 제목도 함께 올라가서, 글자를 키워도 고를 자리가 남는다).
  /// 단계마다 목록을 새로 만들어, 앞 단계에서 굴린 만큼 내려간 채로 시작하지 않게 한다.
  Widget _list(Widget header, List<Widget> children) => ListView(
        key: ValueKey(_step),
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
        children: [header, const SizedBox(height: 14), ...children],
      );

  /// 목록 대신 가운데에 하나를 보여 줄 때 (불러오는 중, 다시 시도).
  Widget _framed(Widget header, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 0), child: header),
          Expanded(child: child),
        ],
      );

  /// '기타'를 골랐을 때 나타나는 직접 입력 칸.
  Widget _otherField(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 30,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: '직접 입력', hintText: hint),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _canProceed ? _next() : null,
      ),
    );
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(
          text,
          style: TextStyle(fontSize: 14, height: 1.45, color: MediumColors.of(context).textSecondary),
        ),
      );

  Widget _buildStep(Widget header) {
    return switch (_step) {
      FindStep.types => _list(header, [
          for (final t in DisabilityType.values) ...[
            OptionTile(
              label: t.label,
              selected: _types.contains(t),
              onTap: () => setState(() {
                _disabilityTouched = true;
                _types.contains(t) ? _types.remove(t) : _types.add(t);
              }),
            ),
            if (t == DisabilityType.other && _types.contains(t))
              _otherField(_otherDisability, '예: 척수장애, 희귀질환'),
          ],
        ]),
      FindStep.severity => _list(header, [
          for (final s in Severity.values)
            OptionTile(
              label: s.label,
              hint: s.hint,
              style: OptionStyle.single,
              selected: _severity == s,
              onTap: () => setState(() {
                _disabilityTouched = true;
                _severity = s;
              }),
            ),
        ]),
      FindStep.need => _list(header, [
          for (final n in CareNeed.values) ...[
            OptionTile(
              label: n.label,
              hint: n.hint,
              style: OptionStyle.single,
              selected: _need == n,
              onTap: () => setState(() => _need = n),
            ),
            if (n == CareNeed.other && _need == n)
              _otherField(_otherNeed, '예: 허리 통증, 피부 질환'),
          ],
        ]),
      FindStep.age => _list(header, [
          for (final a in AgeGroup.values)
            OptionTile(
              label: a.label,
              hint: a.hint,
              style: OptionStyle.single,
              selected: _age == a,
              onTap: () => setState(() => _age = a),
            ),
        ]),
      FindStep.facilities => _facilityStep(header),
      FindStep.region => _regionStep(header),
      FindStep.district => _list(header, [
          OptionTile(
            label: '${_region!.name} 전체',
            style: OptionStyle.single,
            selected: identical(_area, _region),
            onTap: () => setState(() => _area = _region),
          ),
          for (final d in _region!.districts)
            OptionTile(
              label: d.name,
              style: OptionStyle.single,
              selected: identical(_area, d),
              onTap: () => setState(() => _area = d),
            ),
        ]),
    };
  }

  Widget _facilityStep(Widget header) {
    final shown = _facilities ?? _suggested;
    return _list(header, [
      for (final f in Facility.values)
        OptionTile(
          label: f.label,
          selected: shown.contains(f),
          onTap: () => setState(() {
            _facilities = {...shown};
            shown.contains(f) ? _facilities!.remove(f) : _facilities!.add(f);
          }),
        ),
      if (_facilities != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _facilities = null),
            child: const Text('처음 골라 둔 대로 되돌리기'),
          ),
        ),
      _note('편의시설 정보가 아직 없는 병원이 많아요. 정보가 없는 병원은 순서를 낮추지 않고 '
          '‘정보 없음’으로 알려 드려요.'),
    ]);
  }

  Widget _regionStep(Widget header) {
    return FutureBuilder(
      future: _regions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _framed(
            header,
            RetryMessage(
              message: '지역 정보를 불러오지 못했어요.',
              // setState 안에서 Future 를 돌려주면 안 되므로 블록으로 쓴다.
              onRetry: () => setState(() {
                _regions = _services.repository.loadRegions();
              }),
            ),
          );
        }
        if (!snapshot.hasData) {
          return _framed(header, const Center(child: CircularProgressIndicator()));
        }
        final regions = snapshot.data!;
        return _list(header, [
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: locating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const DesignIcon(DesignIcons.pin, size: 20, strokeWidth: 2.2),
            label: Text(locating ? '현재 위치를 확인하고 있어요' : '현재 위치로 찾기'),
            onPressed: locating ? null : () => showResults(_conditions()),
          ),
          _note('또는 지역을 직접 고르세요'),
          for (final r in regions)
            OptionTile(
              label: r.name,
              style: OptionStyle.single,
              selected: identical(_region, r),
              onTap: () => setState(() {
                if (!identical(r, _region)) _area = null;
                _region = r;
              }),
            ),
        ]);
      },
    );
  }
}
