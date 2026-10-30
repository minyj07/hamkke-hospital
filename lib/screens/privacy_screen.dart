import 'package:flutter/material.dart';

import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';

/// 개인정보 처리방침. 앱은 개인정보를 모으지 않으므로 무엇을 어디에 두는지를 알린다.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = [
    (
      '모으는 개인정보: 없어요',
      '메디움은 회원 가입이 없고, 이름·장애 정보·위치 같은 개인정보를 서버로 보내거나 모으지 않아요. '
          '사용 통계나 광고 도구도 쓰지 않아요.',
    ),
    (
      '이 휴대폰에만 두는 정보',
      '나의 진료 카드는 휴대폰의 보안 저장소에 암호화해서 둬요. 지난번 검색 조건, 즐겨찾기, 최근 본 병원, '
          '화면 설정은 앱 전용 저장 공간에 둬요. 화면 설정을 뺀 나머지는 휴대폰 백업에도 넣지 않아요.',
    ),
    (
      'AI로 말해서 찾기',
      '상황을 글로 적으면 메디움 안에 든 AI가 이 휴대폰에서만 읽고 장애 유형·진료·편의시설 같은 조건을 알아내요. '
          '적은 글은 서버로 보내거나 저장하지 않아요. 그 조건으로 찾으면 알아낸 조건만 지난번 검색 조건으로 저장해요.',
    ),
    (
      '위치',
      '‘현재 위치로 찾기’나 홈의 ‘현재 위치로 보기’를 누를 때만 위치를 확인하고, 가까운 병원까지의 거리를 계산하는 데만 써요. '
          '위치는 저장하거나 보내지 않아요.',
    ),
    (
      '인터넷을 쓰는 때',
      '새 병원 정보가 있는지 GitHub(raw.githubusercontent.com)에 올린 공개 데이터 파일을 확인하고 내려받아요. '
          '이때 개인정보는 보내지 않지만, 인터넷 연결의 성격상 접속 기록(IP 주소)은 GitHub에 남을 수 있어요. '
          '지도 보기를 쓰면 네이버 지도가 지도 그림을 받아 와요.',
    ),
    (
      '다른 앱으로 넘기는 것',
      '전화, 길찾기, 지도, 공유, 메일은 휴대폰의 다른 앱(전화, 네이버 지도, 카카오맵, 메일 앱 등)이 처리해요. '
          '그 앱으로 넘어간 뒤의 정보는 그 앱의 처리방침을 따라요.',
    ),
    (
      '정보 오류 신고·문의',
      '‘정보가 틀렸어요’는 휴대폰의 메일 앱으로 보내요. 메일에는 병원 정보, 고른 항목, 직접 쓴 내용, '
          '앱 버전만 들어가고 보내기 전에 확인할 수 있어요. 받은 메일은 병원 정보를 고치고 답장하는 데만 써요.',
    ),
    (
      '내 정보 지우기',
      '설정의 ‘내 정보 전부 지우기’로 언제든 지울 수 있고, 앱을 지우면 함께 지워져요.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final contactEmail = AppScope.of(context).contactEmail;
    final small = TextStyle(fontSize: 13, color: c.textSecondary);
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 처리방침')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        children: [
          for (final (title, body) in _sections) ...[
            SectionTitle(title),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(fontSize: 15, height: 1.6, color: c.text)),
            const SizedBox(height: 26),
          ],
          if (contactEmail.isNotEmpty) Text('문의: $contactEmail', style: small),
          Text('시행일: 2026년 10월 27일', style: small),
        ],
      ),
    );
  }
}
