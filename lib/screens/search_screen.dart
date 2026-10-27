import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../services/hospital_search.dart';
import 'app_scope.dart';
import 'data_notice.dart';
import 'hospital_detail_screen.dart';
import 'retry_message.dart';

/// 조건을 고르지 않고 병원 이름(과 지역·종별)으로 바로 찾는 화면.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  /// 한 번에 보여줄 결과 수. 더 많으면 검색어를 좁히게 한다.
  static const _shown = 50;

  late final _repository = AppScope.of(context).repository;
  late Future<(List<SearchEntry>, Map<String, String>)> _data = _load();
  final _query = TextEditingController();
  bool _opening = false;

  /// 검색 색인과 시·도 코드 → 이름.
  Future<(List<SearchEntry>, Map<String, String>)> _load() async {
    final (entries, regions) =
        await (_repository.loadSearchIndex(), _repository.loadRegions()).wait;
    return (entries, {for (final r in regions) r.code: r.name});
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// 고른 병원의 자세한 정보는 그 시·도 파일에서 읽는다.
  Future<void> _open(SearchEntry e) async {
    if (_opening) return;
    setState(() => _opening = true);
    Hospital? hospital;
    try {
      hospital = await _repository.findHospital(e.region, e.id);
    } catch (_) {
      // 아래에서 안내한다.
    }
    if (!mounted) return;
    setState(() => _opening = false);
    if (hospital == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('병원 정보를 불러오지 못했어요. 다시 눌러 주세요.'),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HospitalDetailScreen(hospital: hospital!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('병원 이름으로 찾기')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: '병원 이름',
                hintText: '예: 서울대병원, 강남 정형외과',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: '검색어 지우기',
                        onPressed: () => setState(_query.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_opening) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return RetryMessage(
                    message: '검색 정보를 불러오지 못했어요.',
                    onRetry: () => setState(() {
                      _data = _load();
                    }),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final (entries, regionNames) = snapshot.data!;
                return _results(entries, regionNames);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(List<SearchEntry> entries, Map<String, String> regionNames) {
    final query = _query.text.trim();
    if (query.isEmpty) {
      return const _Message('병원 이름이나 지역을 입력하세요.\n띄어 쓰면 여러 말로 찾아요 (예: 강남 정형외과).');
    }
    final hits = searchHospitals(entries, query);
    if (hits.isEmpty) {
      return const _Message('찾는 병원이 없어요.\n이름을 줄이거나 띄어 써 보세요.');
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(hits.length > _shown
              ? '${hits.length}곳 중 $_shown곳만 보여줘요. 지역이나 이름을 더 적어 주세요.'
              : '${hits.length}곳을 찾았어요.'),
        ),
        for (final e in hits.take(_shown))
          ListTile(
            title: Text(e.name),
            subtitle: Text([
              e.kind,
              '${regionNames[e.region] ?? ''} ${e.district}'.trim(),
            ].where((s) => s.isNotEmpty).join(' · ')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(e),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: DataNotice(),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
