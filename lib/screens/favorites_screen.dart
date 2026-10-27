import 'package:flutter/material.dart';

import '../data/favorites.dart';
import '../data/hospital_repository.dart';
import '../models/hospital.dart';
import 'hospital_detail_screen.dart';

/// 즐겨찾기한 병원 목록. 열 때마다 지금 데이터에서 다시 읽는다.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.repository, required this.favorites});

  final HospitalRepository repository;
  final Favorites favorites;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _opening = false;

  Future<void> _open(FavoriteHospital f) async {
    if (_opening) return;
    setState(() => _opening = true);
    Hospital? hospital;
    var failed = false;
    try {
      hospital = await widget.repository.findHospital(f.region, f.id);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() => _opening = false);
    final messenger = ScaffoldMessenger.of(context);
    if (failed) {
      messenger.showSnackBar(const SnackBar(
        content: Text('병원 정보를 불러오지 못했어요. 다시 눌러 주세요.'),
      ));
    } else if (hospital == null) {
      messenger.showSnackBar(SnackBar(
        content: Text('${f.name} 정보가 지금 데이터에 없어요. 문을 닫았거나 이름이 바뀌었을 수 있어요.'),
        action: SnackBarAction(
          label: '즐겨찾기에서 빼기',
          onPressed: () => widget.favorites.remove(f.id),
        ),
      ));
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HospitalDetailScreen(hospital: hospital!, favorites: widget.favorites),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('즐겨찾기')),
      body: ListenableBuilder(
        listenable: widget.favorites,
        builder: (context, _) {
          final items = widget.favorites.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '즐겨찾기한 병원이 없어요.\n병원 정보 화면 위쪽의 별을 누르면 여기에 모여요.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            children: [
              if (_opening) const LinearProgressIndicator(),
              for (final f in items)
                ListTile(
                  title: Text(f.name),
                  subtitle: Text([f.kind, f.address].where((s) => s.isNotEmpty).join(' · ')),
                  onTap: () => _open(f),
                  trailing: IconButton(
                    icon: const Icon(Icons.star),
                    tooltip: '${f.name} 즐겨찾기에서 빼기',
                    onPressed: () => widget.favorites.remove(f.id),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
