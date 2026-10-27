import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/data_store.dart';
import 'package:hamkke_hospital/data/last_search_store.dart';
import 'package:hamkke_hospital/data/saved_hospitals.dart';

/// 휴대폰 백업에서 빼는 설정이 앱이 실제로 쓰는 파일과 맞는지 본다.
/// 파일 이름만 바꾸고 규칙을 그대로 두면 장애 정보가 다시 백업에 들어간다.
void main() {
  int count(String text, String pattern) => pattern.allMatches(text).length;

  test('안드로이드 12 이상: 백업과 기기 이전 모두에서 뺀다', () {
    final xml =
        File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    expect(count(xml, 'path="$lastSearchFileName"'), 2);
    expect(count(xml, 'path="$favoritesFileName"'), 2);
    expect(count(xml, 'path="$recentFileName"'), 2);
    expect(count(xml, 'path="$dataDirectoryName/"'), 2);
    // 진료 카드는 flutter_secure_storage 가 이 두 SharedPreferences 에 암호화해서 둔다.
    expect(count(xml, 'domain="sharedpref" path="FlutterSecureStorage.xml"'), 2);
    expect(count(xml, 'domain="sharedpref" path="FlutterSecureKeyStorage.xml"'), 2);
  });

  test('안드로이드 11 이하: 자동 백업에서 뺀다', () {
    final xml = File('android/app/src/main/res/xml/backup_rules.xml').readAsStringSync();
    expect(count(xml, 'path="$lastSearchFileName"'), 1);
    expect(count(xml, 'path="$favoritesFileName"'), 1);
    expect(count(xml, 'path="$recentFileName"'), 1);
    expect(count(xml, 'path="$dataDirectoryName/"'), 1);
    expect(count(xml, 'domain="sharedpref" path="FlutterSecureStorage.xml"'), 1);
    expect(count(xml, 'domain="sharedpref" path="FlutterSecureKeyStorage.xml"'), 1);
  });

  test('안드로이드 매니페스트가 두 규칙을 쓴다', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));
  });

  test('iOS: 파일이 든 Application Support 폴더를 백업에서 빼고, 진료 카드는 이 기기에서만 읽는다', () {
    final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(swift, contains('.applicationSupportDirectory'));
    expect(swift, contains('isExcludedFromBackup = true'));
    final store = File('lib/data/care_card_store.dart').readAsStringSync();
    expect(store, contains('KeychainAccessibility.first_unlock_this_device'));
  });
}
