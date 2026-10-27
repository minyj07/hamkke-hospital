import 'dart:async';

import 'package:flutter/material.dart';

import '../data/regions.dart';
import '../models/search_conditions.dart';
import '../services/location.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'find_screen.dart';
import 'results_screen.dart';

/// 조건으로 병원을 찾아 결과 화면을 연다. 홈의 '지난번 조건으로 다시 찾기'와 병원 찾기의 마지막 단계가 쓴다.
mixin ResultsLauncher<T extends StatefulWidget> on State<T> {
  /// 현재 위치를 확인하는 중인지. 누른 버튼에 보여 준다.
  bool locating = false;
  bool _searching = false;

  void tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// [c] 로 찾아 결과 화면을 열고, 마지막 조건으로 저장한다.
  /// 지역은 지금의 지역 데이터에서 다시 찾고, 현재 위치로 찾는 조건이면 위치를 새로 얻는다.
  Future<void> showResults(SearchConditions c) async {
    if (_searching) return; // 두 번 눌러도 결과 화면은 하나만 연다.
    _searching = true;
    try {
      final services = AppScope.of(context);
      final List<Region> regions;
      try {
        // 저장소는 실패한 읽기를 기억하지 않으므로, 다시 누르면 다시 읽는다.
        regions = await services.repository.loadRegions();
      } catch (_) {
        if (mounted) tell('지역 정보를 불러오지 못했어요. 다시 눌러 주세요.');
        return;
      }
      if (!mounted) return;

      final Region region;
      Area? district, location;
      var nearby = const <Region>[];
      if (c.nearMe) {
        setState(() => locating = true);
        final here = await services.locationService.current();
        if (!mounted) return;
        setState(() => locating = false);
        final near =
            here.error == null ? regionsNear(regions, here.lat, here.lng) : null;
        if (near == null) {
          tell(here.error ?? '현재 위치 근처의 병원 정보가 없어요. 지역을 직접 골라 주세요.');
          return;
        }
        region = near.region;
        nearby = near.nearby;
        location = Area('현재 위치', here.lat, here.lng);
      } else {
        final found = regions.where((r) => r.code == c.regionCode).firstOrNull;
        district = found?.districts.where((d) => d.name == c.districtName).firstOrNull;
        if (found == null || (c.districtName != null && district == null)) {
          tell('지역 정보가 바뀌었어요. 지역을 다시 골라 주세요.');
          return;
        }
        region = found;
      }

      unawaited(services.lastSearch.save(c));
      final exit = await Navigator.of(context).push<ResultsExit>(MaterialPageRoute(
        builder: (_) => ResultsScreen(
          profile: c.toProfile(
            region: region,
            district: district,
            location: location,
            nearbyRegions: nearby,
          ),
        ),
      ));
      if (exit == ResultsExit.changeNeed && mounted) {
        AppShell.of(context).editSearch(c, FindStep.need);
      }
    } finally {
      _searching = false;
    }
  }
}
