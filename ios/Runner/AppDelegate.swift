import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeAppDataFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// 저장한 검색 조건(last_search.json), 즐겨찾기·최근 본 병원, 내려받은 병원 데이터(hospital_data/)는
  /// 앱이 Application Support 에 둔다. 장애·건강 정보가 들어 있고 다시 받으면 되는 데이터라 iCloud·컴퓨터
  /// 백업에서 뺀다. 파일은 저장할 때마다 새 파일로 바뀌므로 파일이 아니라 폴더에 표시한다.
  /// 진료 카드는 키체인에 이 기기에서만 읽게(ThisDeviceOnly) 둔다 (lib/data/care_card_store.dart).
  /// 백업해야 하는 데이터가 생기면 이 폴더가 아닌 곳(Documents 등)에 둔다.
  private func excludeAppDataFromBackup() {
    let fileManager = FileManager.default
    guard var url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { return }
    do {
      try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
    } catch {
      NSLog("앱 데이터를 백업에서 빼지 못했어요: %@", error.localizedDescription)
    }
  }
}
