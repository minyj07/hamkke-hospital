import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'care_card_screen.dart';

/// 앱 잠금. 잠겨 있으면 앱의 모든 화면 대신 잠금 화면을 보여 준다.
/// 앱을 켤 때, 그리고 1분 넘게 다른 앱에 있다가 돌아올 때 잠근다 (전화를 걸러 잠깐 나갔다 오는 정도는 두지 않는다).
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  static const _grace = Duration(minutes: 1);

  late final AppServices _services = AppScope.of(context);
  late bool _locked = _services.settings.appLock;
  DateTime? _hiddenAt;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _hiddenAt ??= DateTime.now(),
      onShow: () {
        final hiddenAt = _hiddenAt;
        _hiddenAt = null;
        if (_services.settings.appLock &&
            hiddenAt != null &&
            DateTime.now().difference(hiddenAt) >= _grace) {
          setState(() => _locked = true);
        }
      },
    );
    _services.settings.addListener(_settingsChanged);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _services.settings.removeListener(_settingsChanged);
    super.dispose();
  }

  /// 잠금을 끄면 바로 연다.
  void _settingsChanged() {
    if (!_services.settings.appLock && _locked) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 잠겨 있는 동안 앱 화면은 그대로 두되 보이지도, 화면낭독기로 읽히지도 않게 한다.
        Offstage(
          offstage: _locked,
          child: TickerMode(enabled: !_locked, child: widget.child),
        ),
        if (_locked)
          // 잠금 화면에서 '병원에 보여 주기'를 열 수 있게 따로 화면 이동을 둔다.
          HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => LockScreen(onUnlocked: () => setState(() => _locked = false)),
              ),
            ),
          ),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final AppServices _services = AppScope.of(context);
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    // 잠금 화면이 뜨면 한 번은 바로 지문·비밀번호 창을 띄운다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await _services.appLock.unlock();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _message = '잠금을 풀지 못했어요. ‘잠금 풀기’를 다시 눌러 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showCard =
        _services.settings.showCardWhenLocked && _services.careCard.card != null;
    final tall = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text('함께병원이 잠겨 있어요',
                      style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 8),
                const Text('지문·얼굴이나 휴대폰 비밀번호로 잠금을 풀어 주세요.',
                    textAlign: TextAlign.center),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(_message!, textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: tall,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('잠금 풀기'),
                  onPressed: _busy ? null : _unlock,
                ),
                if (showCard) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: tall,
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('병원에 보여 주기'),
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ShowCardScreen())),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
