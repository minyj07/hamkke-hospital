import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 설정 파일. 장애·건강 정보가 없어서 휴대폰 백업에 넣는다 (새 휴대폰에서도 글자 크기 등이 그대로다).
const settingsFileName = 'settings.json';

/// 저장이 안 되어도 앱은 그대로 써야 하므로, 실패하면 기록만 남기고 오류를 던지지 않는다.
abstract class SettingsStore {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> settings);
}

/// 앱 전용 저장 공간(Application Support)의 [settingsFileName] 에 둔다.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> get _file async => File('${(await _directory()).path}/$settingsFileName');

  @override
  Future<Map<String, dynamic>> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return {};
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('설정을 읽지 못했어요: $e');
      return {};
    }
  }

  @override
  Future<void> save(Map<String, dynamic> settings) async {
    try {
      final file = await _file;
      await file.parent.create(recursive: true);
      final part = File('${file.path}.part');
      await part.writeAsString(jsonEncode(settings), flush: true);
      await part.rename(file.path);
    } catch (e) {
      debugPrint('설정을 저장하지 못했어요: $e');
    }
  }
}

/// 앱 설정. 바뀌면 알려서 글자 크기·대비 등을 바로 바꾼다.
class AppSettings extends ChangeNotifier {
  AppSettings(this._store);

  final SettingsStore _store;

  static const minTextScale = 1.0;
  static const maxTextScale = 2.0;

  double? _textScale;
  bool _highContrast = false;
  bool _onboardingDone = false;
  bool _appLock = false;
  bool _showCardWhenLocked = false;

  /// 앱 안에서 정한 글자 크기 (1.0~2.0배). null 이면 휴대폰 설정을 따른다.
  double? get textScale => _textScale;

  bool get highContrast => _highContrast;

  /// 첫 실행 안내를 봤는지.
  bool get onboardingDone => _onboardingDone;

  /// 앱을 열 때 지문·얼굴·휴대폰 비밀번호로 잠금을 풀게 할지.
  bool get appLock => _appLock;

  /// 잠겨 있어도 진료 카드의 '병원에 보여 주기'를 볼 수 있게 할지. 기본은 보이지 않는다.
  bool get showCardWhenLocked => _showCardWhenLocked;

  Future<void> load() async {
    final json = await _store.load();
    final scale = (json['textScale'] as num?)?.toDouble();
    _textScale = scale?.clamp(minTextScale, maxTextScale);
    _highContrast = json['highContrast'] == true;
    _onboardingDone = json['onboardingDone'] == true;
    _appLock = json['appLock'] == true;
    _showCardWhenLocked = json['showCardWhenLocked'] == true;
    notifyListeners();
  }

  Future<void> setTextScale(double? value) =>
      _change(() => _textScale = value?.clamp(minTextScale, maxTextScale));

  Future<void> setHighContrast(bool on) => _change(() => _highContrast = on);

  Future<void> finishOnboarding() => _change(() => _onboardingDone = true);

  Future<void> setAppLock(bool on) => _change(() => _appLock = on);

  Future<void> setShowCardWhenLocked(bool on) => _change(() => _showCardWhenLocked = on);

  Future<void> _change(void Function() apply) async {
    apply();
    notifyListeners();
    await _store.save({
      if (_textScale != null) 'textScale': _textScale,
      'highContrast': _highContrast,
      'onboardingDone': _onboardingDone,
      'appLock': _appLock,
      'showCardWhenLocked': _showCardWhenLocked,
    });
  }
}
