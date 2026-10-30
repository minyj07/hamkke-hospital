import 'package:flutter/material.dart';

import '../data/data_store.dart';
import '../data/regions.dart';
import 'app_scope.dart';
import 'hospital_actions.dart';
import 'privacy_screen.dart';
import '../ui/tokens.dart';

/// 글자 크기·고대비·앱 잠금, 내 정보 지우기, 병원 정보 기준일·출처, 개인정보 처리방침·라이선스·문의.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AppServices _services = AppScope.of(context);
  late Future<DataInfo> _info = _services.repository.loadInfo();
  bool _checking = false;
  String? _updateMessage;

  /// 새 병원 정보가 있는지 바로 확인한다. 평소에는 앱을 켤 때 저절로 받는다.
  Future<void> _checkUpdate() async {
    setState(() {
      _checking = true;
      _updateMessage = null;
    });
    final result = await _services.repository.update();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _info = _services.repository.loadInfo();
      _updateMessage = switch (result) {
        UpdateResult.updated => '새 병원 정보를 받았어요.',
        UpdateResult.upToDate => '이미 최신 정보예요.',
        UpdateResult.failed => '확인하지 못했어요. 인터넷 연결을 확인하고 다시 눌러 주세요.',
        UpdateResult.disabled => '이 앱은 설치할 때 들어 있던 정보만 써요.',
      };
    });
  }

  void _tell(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _setAppLock(bool on) async {
    final settings = _services.settings;
    if (!on) {
      await settings.setAppLock(false);
      return;
    }
    if (!await _services.appLock.isAvailable()) {
      _tell('휴대폰에 화면 잠금(PIN·패턴·지문 등)을 먼저 설정해 주세요.');
      return;
    }
    // 켜기 전에 한 번 풀어 봐서, 잠금을 못 푸는 상태로 잠기지 않게 한다.
    if (await _services.appLock.unlock()) await settings.setAppLock(true);
  }

  Future<void> _clearAll() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // 글자를 크게 키운 작은 화면에서는 본문이 다 들어가지 않으므로 굴려서 볼 수 있게 한다.
        scrollable: true,
        title: const Text('내 정보를 모두 지울까요?'),
        content: const Text('진료 카드, 지난번 검색 조건, 즐겨찾기, 최근 본 병원을 지워요. '
            '지우면 되돌릴 수 없어요. 글자 크기 같은 화면 설정은 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _services.clearPersonalData();
    if (mounted) _tell('내 정보를 모두 지웠어요.');
  }

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final settings = _services.settings;
    // 묶음 제목 (디자인의 섹션 제목 17/800 을 목록에 맞게 짙은 초록으로).
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 6),
          child: Semantics(
            header: true,
            child: Text(text, style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: c.brandDeep,
            )),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final scale = settings.textScale;
          final percent = scale == null ? null : (scale * 100).round();
          return ListView(
            children: [
              header('화면'),
              SwitchListTile(
                title: const Text('휴대폰 글자 크기 따르기'),
                subtitle: const Text('끄면 앱 안에서 글자 크기를 100%에서 200%까지 정해요.'),
                value: scale == null,
                onChanged: (on) => settings.setTextScale(on ? null : 1.0),
              ),
              if (scale != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text('글자 크기 $percent%', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Slider(
                  value: scale,
                  min: 1.0,
                  max: 2.0,
                  divisions: 4,
                  label: '$percent%',
                  semanticFormatterCallback: (v) => '글자 크기 ${(v * 100).round()}%',
                  onChanged: settings.setTextScale,
                ),
              ],
              SwitchListTile(
                title: const Text('고대비 모드'),
                subtitle: const Text('글자와 배경의 색 차이를 크게 해요.'),
                value: settings.highContrast,
                onChanged: settings.setHighContrast,
              ),
              header('개인정보'),
              SwitchListTile(
                title: const Text('앱 잠금'),
                subtitle: const Text('앱을 열 때 지문·얼굴이나 휴대폰 비밀번호로 잠금을 풀어요.'),
                value: settings.appLock,
                onChanged: _setAppLock,
              ),
              SwitchListTile(
                title: const Text('잠겨 있어도 ‘병원에 보여 주기’ 열기'),
                subtitle: const Text('잠금을 풀지 않고 진료 카드의 보여 주기 화면만 열 수 있어요. '
                    '휴대폰을 든 다른 사람도 볼 수 있으니 필요할 때만 켜세요.'),
                value: settings.showCardWhenLocked,
                onChanged: settings.appLock ? settings.setShowCardWhenLocked : null,
              ),
              ListTile(
                leading: const _IconBox(Icons.delete_outline),
                title: const Text('내 정보 전부 지우기'),
                subtitle: const Text('진료 카드, 지난번 검색 조건, 즐겨찾기, 최근 본 병원'),
                onTap: _clearAll,
              ),
              header('병원 정보'),
              FutureBuilder(
                future: _info,
                builder: (context, snapshot) => ListTile(
                  leading: const _IconBox(Icons.event_note),
                  title: Text(snapshot.hasData
                      ? '${snapshot.data!.generatedAt} 기준 공공데이터'
                      : '기준일을 확인하고 있어요'),
                  subtitle: snapshot.hasData
                      ? Text('자료: ${snapshot.data!.sources.join(', ')}')
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('새 병원 정보는 앱을 켤 때 저절로 받아요.',
                        style: TextStyle(fontSize: 14, color: c.textSecondary)),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _checking ? null : _checkUpdate,
                      child: Text(_checking ? '확인하고 있어요' : '지금 새 정보 확인하기'),
                    ),
                    if (_updateMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        // 화면 읽기 프로그램이 결과를 바로 읽어 주게 한다.
                        child: Semantics(liveRegion: true, child: Text(_updateMessage!)),
                      ),
                  ],
                ),
              ),
              header('앱 정보'),
              ListTile(
                leading: const _IconBox(Icons.privacy_tip_outlined),
                title: const Text('개인정보 처리방침'),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacyScreen())),
              ),
              ListTile(
                leading: const _IconBox(Icons.description_outlined),
                title: const Text('오픈소스 라이선스'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: appName,
                  applicationVersion: _services.appVersion,
                ),
              ),
              if (_services.contactEmail.isNotEmpty)
                ListTile(
                  leading: const _IconBox(Icons.mail_outline),
                  title: const Text('문의하기'),
                  subtitle: Text(_services.contactEmail),
                  onTap: () => openExternal(context, Uri.parse(
                      'mailto:${_services.contactEmail}?subject=${Uri.encodeComponent('[$appName 문의]')}')),
                ),
              if (_services.appVersion.isNotEmpty)
                ListTile(
                  leading: const _IconBox(Icons.info_outline),
                  title: const Text('앱 버전'),
                  subtitle: Text(_services.appVersion),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// 설정 줄 앞의 아이콘 (디자인: 연한 초록 36px 네모 속 짙은 초록 아이콘).
class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20, color: c.brandDeep),
    );
  }
}
