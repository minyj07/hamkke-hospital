import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// 앱 잠금. 휴대폰에 설정한 지문·얼굴·비밀번호(PIN·패턴)로 푼다. 앱이 따로 비밀번호를 두지 않는다.
abstract class AppLock {
  /// 휴대폰에 잠금이 설정되어 있어 앱 잠금을 쓸 수 있는지.
  Future<bool> isAvailable();

  /// 잠금을 푼다. 풀었으면 true, 취소했거나 실패했으면 false.
  Future<bool> unlock();
}

class DeviceAppLock implements AppLock {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('잠금을 쓸 수 있는지 확인하지 못했어요: $e');
      return false;
    }
  }

  @override
  Future<bool> unlock() async {
    try {
      return await _auth.authenticate(
        localizedReason: '함께병원 잠금을 풀어 주세요',
        // 휴대폰 비밀번호 화면으로 넘어갔다 와도 이어서 확인한다.
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('잠금을 풀지 못했어요: $e');
      return false;
    }
  }
}
