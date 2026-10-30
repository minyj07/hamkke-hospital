import 'package:flutter/material.dart';

import '../data/saved_hospitals.dart';
import '../models/hospital.dart';
import 'app_scope.dart';
import 'data_notice.dart';
import 'hospital_actions.dart';
import 'hospital_detail_screen.dart';
import '../ui/icons.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';

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
    final c = MediumColors.of(context);
    final muted = TextStyle(fontSize: 14, height: 1.5, color: c.textMuted);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([_services.favorites, _services.recent]),
          builder: (context, _) {
            final favorites = _services.favorites.items;
            final recent = _services.recent.items;
            return ListView(
              padding: const EdgeInsets.fromLTRB(22, 34, 22, 0),
              children: [
                PageHeading('즐겨찾기', subtitle: '저장한 병원 ${favorites.length}곳'),
                const SizedBox(height: 20),
                if (_loading) const LinearProgressIndicator(),
                if (favorites.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      '아직 저장한 병원이 없어요\n홈이나 병원 정보에서 ♡를 눌러 저장해 보세요',
                      semanticsLabel: '아직 저장한 병원이 없어요. 홈이나 병원 정보에서 하트를 눌러 저장해 보세요.',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
                  ),
                for (final f in favorites) ...[
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
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 18),
                SectionTitle(
                  '최근 본 병원',
                  trailing: recent.isEmpty
                      ? null
                      : TextButton(onPressed: _clearRecent, child: const Text('기록 지우기')),
                ),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  Text('최근 본 병원이 없어요. 병원 정보를 열면 최근 ${RecentHospitals.limit}곳까지 여기에 남아요.',
                      style: muted),
                for (final r in recent) ...[
                  HospitalTile(
                    id: r.id,
                    name: r.name,
                    subtitle: [r.kind, r.address].where((s) => s.isNotEmpty).join(' · '),
                    onTap: () => _open(r),
                  ),
                  const SizedBox(height: 10),
                ],
                const DataNotice(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 즐겨찾기한 병원 (디자인: 사진 자리·이름·설명·빨간 하트). 아래에서 바로 전화·길찾기를 한다.
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
    final small = OutlinedButton.styleFrom(
      minimumSize: const Size(48, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
    return HospitalTile(
      id: saved.id,
      name: saved.name,
      subtitle: [saved.kind, saved.address].where((s) => s.isNotEmpty).join(' · '),
      showTone: true,
      onTap: onOpen,
      trailing: HeartButton(name: saved.name, favorite: true, onPressed: onRemove),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              style: small,
              icon: const DesignIcon(DesignIcons.phone, size: 16, strokeWidth: 2.3),
              label: Text('전화', semanticsLabel: '${saved.name}에 전화'),
              onPressed: onCall,
            ),
            OutlinedButton.icon(
              style: small,
              icon: const DesignIcon(DesignIcons.route, size: 16, strokeWidth: 2.3),
              label: Text('길찾기', semanticsLabel: '${saved.name} 길찾기'),
              onPressed: onDirections,
            ),
          ],
        ),
      ),
    );
  }
}
