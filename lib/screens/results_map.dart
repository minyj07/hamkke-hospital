import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../data/regions.dart';
import '../services/recommender.dart';

/// 추천 결과를 네이버 지도에 목록과 같은 번호로 보여 준다. 아래 카드에서 한 곳씩 넘겨 보고 연다.
/// 지도는 화면낭독기로 읽을 수 없으므로 같은 내용을 아래 카드로 읽게 하고, 목록 보기가 기본이다.
class ResultsMap extends StatefulWidget {
  const ResultsMap({
    super.key,
    required this.results,
    required this.origin,
    required this.onOpen,
  });

  final List<Recommendation> results;

  /// 결과가 없을 때 지도의 가운데.
  final Area origin;
  final ValueChanged<Recommendation> onOpen;

  @override
  State<ResultsMap> createState() => _ResultsMapState();
}

class _ResultsMapState extends State<ResultsMap> {
  NaverMapController? _controller;
  final _markers = <NMarker>[];
  int _selected = 0;

  NLatLng _point(int i) {
    final h = widget.results[i].hospital;
    return NLatLng(h.lat, h.lng);
  }

  void _onMapReady(NaverMapController controller) {
    _controller = controller;
    final color = Theme.of(context).colorScheme.primary;
    for (var i = 0; i < widget.results.length; i++) {
      final marker = NMarker(
        id: widget.results[i].hospital.id,
        position: _point(i),
        caption: NOverlayCaption(text: '${i + 1}. ${widget.results[i].hospital.name}'),
        iconTintColor: i == _selected ? color : Colors.transparent,
      );
      marker.setOnTapListener((_) => _select(i));
      _markers.add(marker);
    }
    controller.addOverlayAll(_markers.toSet());
    if (_markers.length > 1) {
      controller.updateCamera(NCameraUpdate.fitBounds(
        NLatLngBounds.from([for (var i = 0; i < _markers.length; i++) _point(i)]),
        padding: const EdgeInsets.all(48),
      ));
    } else if (_markers.length == 1) {
      controller.updateCamera(NCameraUpdate.scrollAndZoomTo(target: _point(0), zoom: 15));
    }
  }

  void _select(int i) {
    if (i == _selected || i < 0 || i >= widget.results.length) return;
    if (_markers.length == widget.results.length) {
      _markers[_selected].setIconTintColor(Colors.transparent);
      _markers[i].setIconTintColor(Theme.of(context).colorScheme.primary);
      _controller?.updateCamera(NCameraUpdate.scrollAndZoomTo(target: _point(i)));
    }
    setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Semantics(
            label: '지도. 추천 병원의 위치를 번호로 보여 줘요. 아래에서 병원을 한 곳씩 넘겨 볼 수 있어요.',
            child: ExcludeSemantics(
              child: NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: NLatLng(widget.origin.lat, widget.origin.lng),
                    zoom: 12,
                  ),
                ),
                onMapReady: _onMapReady,
              ),
            ),
          ),
        ),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('지도에 보여 줄 병원이 없어요. 목록에서 조건을 바꿔 보세요.'),
          )
        else
          _SelectedCard(
            rank: _selected + 1,
            total: results.length,
            rec: results[_selected],
            onPrevious: _selected > 0 ? () => _select(_selected - 1) : null,
            onNext: _selected < results.length - 1 ? () => _select(_selected + 1) : null,
            onOpen: () => widget.onOpen(results[_selected]),
          ),
      ],
    );
  }
}

/// 지도에서 고른 병원. 목록 카드와 같은 내용을 짧게 보여 준다.
class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.rank,
    required this.total,
    required this.rec,
    required this.onPrevious,
    required this.onNext,
    required this.onOpen,
  });

  final int rank;
  final int total;
  final Recommendation rec;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = rec.hospital;
    final tall = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size(48, 56)));
    return Material(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 이전·다음으로 바꾸면 화면낭독기가 새 병원을 읽어 준다.
            Semantics(
              liveRegion: true,
              child: Text('$rank / $total. ${h.name}', style: theme.textTheme.titleMedium),
            ),
            Text([
              if (h.kind.isNotEmpty) h.kind,
              '약 ${rec.distanceKm.toStringAsFixed(1)}km',
              if (rec.reasons.isNotEmpty) rec.reasons.first,
            ].join(' · ')),
            if (rec.missing.isNotEmpty)
              Text('확인 필요 · 없다고 확인됨: ${rec.missing.map((f) => f.label).join(', ')}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: tall,
                    onPressed: onPrevious,
                    child: const Text('이전'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(style: tall, onPressed: onNext, child: const Text('다음')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(style: tall, onPressed: onOpen, child: const Text('자세히 보기')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
