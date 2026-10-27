import 'dart:async';

import 'package:flutter/material.dart';

import '../data/data_store.dart';
import '../data/favorites.dart';
import '../data/hospital_repository.dart';
import '../data/last_search_store.dart';
import '../data/regions.dart';
import '../models/disability.dart';
import '../models/search_conditions.dart';
import '../services/location.dart';
import 'favorites_screen.dart';
import 'results_screen.dart';
import 'retry_message.dart';
import 'search_screen.dart';

/// 장애 유형 → 정도 → 필요한 진료 → 시·도(또는 현재 위치) → 시·군·구 순서로 묻는 화면.
/// 지난번에 찾은 조건이 있으면 맨 위에서 바로 다시 찾을 수 있다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.repository,
    required this.locationService,
    required this.searchStore,
    required this.favorites,
  });

  final HospitalRepository repository;
  final LocationService locationService;
  final LastSearchStore searchStore;
  final Favorites favorites;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _titles = [
    '어떤 장애가 있으신가요?',
    '장애의 정도를 알려주세요',
    '어떤 진료가 필요하신가요?',
    '어디에서 찾을까요?',
    '시·군·구를 골라 주세요',
  ];

  /// 지역 고르기 단계에 보여줄 시·도 목록. 못 불러오면 다시 시도로 새로 받는다.
  late Future<List<Region>> _regions = widget.repository.loadRegions();
  final _otherDisability = TextEditingController();
  final _otherNeed = TextEditingController();

  int _step = 0;
  final Set<DisabilityType> _types = {};
  Severity? _severity;
  CareNeed? _need;
  Region? _region;

  /// 시·군·구. 시·도 전체를 고르면 [_region] 자신이 들어간다.
  Area? _area;
  bool _locating = false;
  bool _searching = false;

  /// 지난번에 찾은 조건.
  SearchConditions? _last;

  @override
  void initState() {
    super.initState();
    widget.searchStore.load().then((last) {
      if (mounted) setState(() => _last = last);
    });
  }

  @override
  void dispose() {
    _otherDisability.dispose();
    _otherNeed.dispose();
    super.dispose();
  }

  bool get _canProceed => switch (_step) {
        0 => _types.isNotEmpty &&
            (!_types.contains(DisabilityType.other) ||
                _otherDisability.text.trim().isNotEmpty),
        1 => _severity != null,
        2 => _need != null &&
            (_need != CareNeed.other || _otherNeed.text.trim().isNotEmpty),
        3 => _region != null,
        _ => _area != null,
      };

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step < _titles.length - 1) {
      setState(() => _step++);
      return;
    }
    _search(_conditions(
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
        regionCode: region?.code,
        regionName: region?.name ?? '',
        districtName: district?.name,
      );

  /// [c] 로 찾아 결과 화면을 열고, 마지막 조건으로 저장한다.
  /// 지역은 지금의 지역 데이터에서 다시 찾고, 현재 위치로 찾는 조건이면 위치를 새로 얻는다.
  Future<void> _search(SearchConditions c) async {
    if (_searching) return; // 두 번 눌러도 결과 화면은 하나만 연다.
    _searching = true;
    try {
      final List<Region> regions;
      try {
        // 저장소는 실패한 읽기를 기억하지 않으므로, 다시 누르면 다시 읽는다.
        regions = await widget.repository.loadRegions();
      } catch (_) {
        if (mounted) _tell('지역 정보를 불러오지 못했어요. 다시 눌러 주세요.');
        return;
      }
      if (!mounted) return;

      final Region region;
      Area? district, location;
      var nearby = const <Region>[];
      if (c.nearMe) {
        setState(() => _locating = true);
        final here = await widget.locationService.current();
        if (!mounted) return;
        setState(() => _locating = false);
        final near =
            here.error == null ? regionsNear(regions, here.lat, here.lng) : null;
        if (near == null) {
          _tell(here.error ?? '현재 위치 근처의 병원 정보가 없어요. 지역을 직접 골라 주세요.');
          return;
        }
        region = near.region;
        nearby = near.nearby;
        location = Area('현재 위치', here.lat, here.lng);
      } else {
        final found = regions.where((r) => r.code == c.regionCode).firstOrNull;
        district = found?.districts.where((d) => d.name == c.districtName).firstOrNull;
        if (found == null || (c.districtName != null && district == null)) {
          _tell('지역 정보가 바뀌었어요. 지역을 다시 골라 주세요.');
          return;
        }
        region = found;
      }

      unawaited(widget.searchStore.save(c));
      setState(() => _last = c);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultsScreen(
          repository: widget.repository,
          favorites: widget.favorites,
          profile: c.toProfile(
            region: region,
            district: district,
            location: location,
            nearbyRegions: nearby,
          ),
        ),
      ));
    } finally {
      _searching = false;
    }
  }

  Future<void> _clearLast() async {
    final cleared = _last;
    if (cleared == null) return;
    setState(() => _last = null);
    await widget.searchStore.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('지난번 조건을 지웠어요.'),
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: () {
          // 그사이 새로 찾았으면 그 조건을 둔다.
          if (!mounted || _last != null) return;
          unawaited(widget.searchStore.save(cleared));
          setState(() => _last = cleared);
        },
      ),
    ));
  }

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('함께병원'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '이전 단계',
                onPressed: () => setState(() => _step--),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '병원 이름으로 찾기',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SearchScreen(
                repository: widget.repository,
                favorites: widget.favorites,
              ),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.star_border),
            tooltip: '즐겨찾기',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FavoritesScreen(
                repository: widget.repository,
                favorites: widget.favorites,
              ),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.update),
            tooltip: '병원 정보 업데이트',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _DataInfoDialog(repository: widget.repository),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '${_titles.length}단계 중 ${_step + 1}단계',
              excludeSemantics: true,
              child: LinearProgressIndicator(value: (_step + 1) / _titles.length),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Semantics(
                header: true,
                child: Text(_titles[_step], style: theme.textTheme.headlineSmall),
              ),
            ),
            if (_step == 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('여러 개를 고를 수 있어요.'),
              ),
            Expanded(child: _buildStep()),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _canProceed ? _next : null,
                child: Text(_step == _titles.length - 1 ? '병원 찾기' : '다음'),
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

  Widget _buildStep() {
    return switch (_step) {
      0 => ListView(
          children: [
            if (_last case final last?)
              _LastSearchCard(
                conditions: last,
                locating: _locating,
                onSearch: () => _search(last),
                onClear: _clearLast,
              ),
            for (final t in DisabilityType.values) ...[
              CheckboxListTile(
                title: Text(t.label),
                value: _types.contains(t),
                onChanged: (on) => setState(
                    () => on! ? _types.add(t) : _types.remove(t)),
              ),
              if (t == DisabilityType.other && _types.contains(t))
                _otherField(_otherDisability, '예: 척수장애, 희귀질환'),
            ],
          ],
        ),
      1 => RadioGroup<Severity>(
          groupValue: _severity,
          onChanged: (v) => setState(() => _severity = v),
          child: ListView(
            children: [
              for (final s in Severity.values)
                RadioListTile<Severity>(
                  value: s,
                  title: Text(s.label),
                  subtitle: Text(s.hint),
                ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('2019년 7월부터 1~6급 장애등급 대신 이 두 가지로 구분해요.'),
              ),
            ],
          ),
        ),
      2 => RadioGroup<CareNeed>(
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
                  _otherField(_otherNeed, '예: 허리 통증, 피부 질환, 아이 진료'),
              ],
            ],
          ),
        ),
      3 => FutureBuilder(
          future: _regions,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return RetryMessage(
                message: '지역 정보를 불러오지 못했어요.',
                onRetry: () => setState(() {
                  _regions = widget.repository.loadRegions();
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
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56)),
                      icon: _locating
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(_locating ? '현재 위치를 확인하고 있어요' : '현재 위치로 찾기'),
                      onPressed: _locating ? null : () => _search(_conditions()),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text('또는 지역을 직접 고르세요'),
                  ),
                  for (final r in regions)
                    RadioListTile<Region>(value: r, title: Text(r.name)),
                ],
              ),
            );
          },
        ),
      _ => RadioGroup<Area>(
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
}

/// 첫 화면의 지난번 조건. 바로 다시 찾거나 지울 수 있다.
class _LastSearchCard extends StatelessWidget {
  const _LastSearchCard({
    required this.conditions,
    required this.locating,
    required this.onSearch,
    required this.onClear,
  });

  final SearchConditions conditions;
  final bool locating;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.filled(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('지난번 조건', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Text(conditions.summary),
            Text('이 휴대폰에 저장하고, 앱 밖으로 보내지 않아요.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: locating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(locating ? '현재 위치를 확인하고 있어요' : '이 조건으로 다시 찾기'),
              onPressed: locating ? null : onSearch,
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: locating ? null : onClear,
              child: const Text('조건 지우기'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 병원 정보가 언제 기준인지 알려주고, 새 정보가 있는지 바로 확인하게 한다.
/// 새 정보는 앱을 켤 때 저절로 받으므로 평소에는 열 필요가 없다.
class _DataInfoDialog extends StatefulWidget {
  const _DataInfoDialog({required this.repository});

  final HospitalRepository repository;

  @override
  State<_DataInfoDialog> createState() => _DataInfoDialogState();
}

class _DataInfoDialogState extends State<_DataInfoDialog> {
  late Future<DataInfo> _info = widget.repository.loadInfo();
  bool _checking = false;
  String? _message;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _message = null;
    });
    final result = await widget.repository.update();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _info = widget.repository.loadInfo();
      _message = switch (result) {
        UpdateResult.updated => '새 병원 정보를 받았어요.',
        UpdateResult.upToDate => '이미 최신 정보예요.',
        UpdateResult.failed => '확인하지 못했어요. 인터넷 연결을 확인하고 다시 눌러 주세요.',
        UpdateResult.disabled => '이 앱은 설치할 때 들어 있던 정보만 써요.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('병원 정보'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder(
            future: _info,
            builder: (context, snapshot) => Text(snapshot.hasData
                ? '${snapshot.data!.generatedAt} 기준 정보예요.'
                : '기준일을 확인하고 있어요.'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            // 화면 읽기 프로그램이 결과를 바로 읽어 주게 한다.
            Semantics(liveRegion: true, child: Text(_message!)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        FilledButton(
          onPressed: _checking ? null : _check,
          child: Text(_checking ? '확인하고 있어요' : '지금 확인하기'),
        ),
      ],
    );
  }
}
