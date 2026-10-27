import 'package:flutter/material.dart';

import '../data/saved_hospitals.dart';
import '../models/hospital.dart';
import 'app_scope.dart';
import 'data_notice.dart';
import 'hospital_actions.dart';
import 'hospital_detail_screen.dart';

/// 즐겨찾기한 병원과 최근 본 병원. 열거나 전화·길찾기를 누를 때마다 지금 데이터에서 다시 읽는다.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final AppServices _services = AppScope.of(context);
  bool _loading = false;

  /// [saved] 병원을 지금 데이터에서 찾아 [use] 한다. 없어졌으면 즐겨찾기에서 뺄 수 있게 안내한다.
  Future<void> _withHospital(SavedHospital saved, void Function(Hospital h) use) async {
    if (_loading) return;
    setState(() => _loading = true);
    Hospital? hospital;
    var failed = false;
    try {
      hospital = await _services.repository.findHospital(saved.region, saved.id);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    final messenger = ScaffoldMessenger.of(context);
    if (failed) {
      messenger.showSnackBar(const SnackBar(
        content: Text('병원 정보를 불러오지 못했어요. 다시 눌러 주세요.'),
      ));
    } else if (hospital == null) {
      messenger.showSnackBar(SnackBar(
        content: Text('${saved.name} 정보가 지금 데이터에 없어요. 문을 닫았거나 이름이 바뀌었을 수 있어요.'),
        action: _services.favorites.contains(saved.id)
            ? SnackBarAction(
                label: '즐겨찾기에서 빼기',
                onPressed: () => _services.favorites.remove(saved.id),
              )
            : null,
      ));
    } else {
      use(hospital);
    }
  }

  void _open(SavedHospital saved) => _withHospital(
        saved,
        (h) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalDetailScreen(hospital: h),
        )),
      );

  Future<void> _clearRecent() async {
    final cleared = _services.recent.items;
    await _services.recent.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('최근 본 병원 기록을 지웠어요.'),
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: () => _services.recent.restore(cleared),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Semantics(
            header: true,
            child: Text(text, style: theme.textTheme.titleLarge),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기')),
      body: ListenableBuilder(
        listenable: Listenable.merge([_services.favorites, _services.recent]),
        builder: (context, _) {
          final favorites = _services.favorites.items;
          final recent = _services.recent.items;
          return ListView(
            children: [
              if (_loading) const LinearProgressIndicator(),
              header('즐겨찾기'),
              if (favorites.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('즐겨찾기한 병원이 없어요.\n병원 정보 화면에서 ‘즐겨찾기에 넣기’를 누르면 여기에 모여요.'),
                ),
              for (final f in favorites)
                _FavoriteCard(
                  saved: f,
                  onOpen: () => _open(f),
                  onCall: () => _withHospital(f, (h) {
                    if (h.phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('전화번호 정보가 없어요.')));
                    } else {
                      callPhone(context, h.phone);
                    }
                  }),
                  onDirections: () => _withHospital(f, (h) => openDirections(context, h)),
                  onRemove: () => _services.favorites.remove(f.id),
                ),
              Row(
                children: [
                  Expanded(child: header('최근 본 병원')),
                  if (recent.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, right: 8),
                      child: TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        onPressed: _clearRecent,
                        child: const Text('기록 지우기'),
                      ),
                    ),
                ],
              ),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('최근 본 병원이 없어요. 병원 정보를 열면 최근 ${RecentHospitals.limit}곳까지 여기에 남아요.'),
                ),
              for (final r in recent)
                ListTile(
                  title: Text(r.name),
                  subtitle: Text([r.kind, r.address].where((s) => s.isNotEmpty).join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(r),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DataNotice(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.saved,
    required this.onOpen,
    required this.onCall,
    required this.onDirections,
    required this.onRemove,
  });

  final SavedHospital saved;
  final VoidCallback onOpen;
  final VoidCallback onCall;
  final VoidCallback onDirections;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tall = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(48, 48)));
    return Card.outlined(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(saved.name),
            subtitle: Text([saved.kind, saved.address].where((s) => s.isNotEmpty).join(' · ')),
            onTap: onOpen,
            trailing: IconButton(
              icon: const Icon(Icons.star),
              tooltip: '${saved.name} 즐겨찾기에서 빼기',
              onPressed: onRemove,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: tall,
                  icon: const Icon(Icons.call),
                  label: Text('전화', semanticsLabel: '${saved.name}에 전화'),
                  onPressed: onCall,
                ),
                OutlinedButton.icon(
                  style: tall,
                  icon: const Icon(Icons.directions),
                  label: Text('길찾기', semanticsLabel: '${saved.name} 길찾기'),
                  onPressed: onDirections,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
