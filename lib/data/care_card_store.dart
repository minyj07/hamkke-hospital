import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/care_card.dart';

/// 진료 카드를 저장해 두었다는 표시 파일. iOS 키체인은 앱을 지워도 남으므로, 다시 설치한 앱이
/// 지난번 카드를 보여 주지 않게 이 파일(앱을 지우면 함께 지워진다)이 있을 때만 카드를 읽는다.
const careCardMarkerFileName = 'care_card_saved';

/// 진료 카드는 장애·건강 정보라 기기의 보안 저장소에 암호화해 둔다.
/// 저장이 안 되어도 앱은 그대로 써야 하므로, 실패하면 기록만 남기고 오류를 던지지 않는다.
abstract class CareCardStore {
  Future<CareCard?> load();
  Future<void> save(CareCard card);
  Future<void> clear();
}

/// 안드로이드는 Keystore 의 키로 암호화한 SharedPreferences(백업에서 뺀다), iOS 는 키체인에 둔다.
class SecureCareCardStore implements CareCardStore {
  SecureCareCardStore({
    FlutterSecureStorage? storage,
    Future<Directory> Function()? directory,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              // 이 기기에서만 읽게 해서 다른 기기나 백업으로 옮겨 가지 않게 한다.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            ),
        _directory = directory ?? getApplicationSupportDirectory;

  static const _key = 'care_card';
  final FlutterSecureStorage _storage;
  final Future<Directory> Function() _directory;

  Future<File> get _marker async =>
      File('${(await _directory()).path}/$careCardMarkerFileName');

  @override
  Future<CareCard?> load() async {
    try {
      if (!await (await _marker).exists()) {
        // 지운 앱이 남긴 카드일 수 있다.
        await _storage.delete(key: _key);
        return null;
      }
      final raw = await _storage.read(key: _key);
      return raw == null ? null : CareCard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('진료 카드를 읽지 못했어요: $e');
      return null;
    }
  }

  @override
  Future<void> save(CareCard card) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(card.toJson()));
      final marker = await _marker;
      await marker.parent.create(recursive: true);
      await marker.writeAsString('1', flush: true);
    } catch (e) {
      debugPrint('진료 카드를 저장하지 못했어요: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
      final marker = await _marker;
      if (await marker.exists()) await marker.delete();
    } catch (e) {
      debugPrint('진료 카드를 지우지 못했어요: $e');
    }
  }
}

/// 나의 진료 카드. 여러 화면이 같은 카드를 보도록 앱에 하나만 두고, 바뀌면 알린다.
class SavedCareCard extends ChangeNotifier {
  SavedCareCard(this._store);

  final CareCardStore _store;
  CareCard? _card;
  late final Future<void> _ready = _store.load().then((card) {
    _card = card;
    notifyListeners();
  });

  /// 저장해 둔 카드를 읽는다. 여러 번 불러도 한 번만 읽는다.
  Future<void> load() => _ready;

  /// 아직 만들지 않았으면 null.
  CareCard? get card => _card;

  Future<void> save(CareCard card) async {
    await _ready;
    _card = card;
    notifyListeners();
    await _store.save(card);
  }

  Future<void> clear() async {
    await _ready;
    _card = null;
    notifyListeners();
    await _store.clear();
  }
}
