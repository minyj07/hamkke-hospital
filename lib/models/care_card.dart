import 'disability.dart';
import 'korean.dart';

/// 의료진에게 바라는 소통 방법. [sentence] 는 '병원에 보여 주기' 화면에 그대로 쓴다.
enum Communication {
  signLanguage('수어', '수어 통역이 필요해요.'),
  writing('필담(글로 쓰기)', '글로 써 주세요.'),
  slowly('천천히 말하기', '천천히, 또박또박 말해 주세요.'),
  lipReading('입 모양 보기', '입 모양이 보이게 마주 보고 말해 주세요.'),
  easyWords('쉬운 말', '쉬운 말로 짧게 설명해 주세요.'),
  largeText('큰 글씨', '글씨를 크게 써 주세요.'),
  readAloud('소리 내어 읽기', '서류는 소리 내어 읽어 주세요.'),
  guardian('보호자와 이야기', '보호자와 함께 이야기해 주세요.');

  const Communication(this.label, this.sentence);
  final String label;
  final String sentence;
}

/// 병원에서 필요한 도움.
enum HelpNeed {
  wheelchair('휠체어 이동', '휠체어로 이동할 때 도와주세요.'),
  transfer('검사대 옮겨 앉기', '검사대나 진료 의자로 옮겨 앉을 때 도와주세요.'),
  guide('길 안내', '진료실과 검사실까지 길을 안내해 주세요.'),
  callMe('차례 알려 주기', '제 차례가 되면 직접 와서 알려 주세요.'),
  quietPlace('조용한 곳에서 기다리기', '조용한 곳에서 기다리게 해 주세요.'),
  shortWait('오래 기다리기 어려움', '오래 기다리기 어려워요.'),
  paperwork('서류 쓰기', '서류 쓰는 것을 도와주세요.');

  const HelpNeed(this.label, this.sentence);
  final String label;
  final String sentence;
}

/// 자주 쓰는 짧은 문장. 누르면 화면 가득 크게 보여 준다.
const commonPhrases = [
  '아파요.',
  '화장실에 가고 싶어요.',
  '다시 말해 주세요.',
  '천천히 말해 주세요.',
  '글로 써 주세요.',
  '잠깐 쉬고 싶어요.',
  '보호자를 불러 주세요.',
  '물을 마시고 싶어요.',
  '네.',
  '아니요.',
  '고맙습니다.',
];

final _typeByName = DisabilityType.values.asNameMap();
final _communicationByName = Communication.values.asNameMap();
final _helpByName = HelpNeed.values.asNameMap();

/// 나의 진료 카드. 병원 접수·진료 때 화면을 의료진에게 보여 준다.
/// 장애·건강 정보라 기기의 보안 저장소에만 둔다 (lib/data/care_card_store.dart). 모든 항목은 비워 둘 수 있다.
class CareCard {
  const CareCard({
    this.name = '',
    this.types = const {},
    this.otherDisability = '',
    this.severity,
    this.communication = const {},
    this.otherCommunication = '',
    this.help = const {},
    this.otherHelp = '',
    this.cautions = '',
    this.conditions = '',
    this.allergies = '',
    this.guardianName = '',
    this.guardianPhone = '',
  });

  /// 이름 또는 불러 주었으면 하는 이름.
  final String name;

  /// 장애 유형·정도. 병원 찾기의 1·2단계를 미리 채운다.
  final Set<DisabilityType> types;
  final String otherDisability;
  final Severity? severity;

  final Set<Communication> communication;
  final String otherCommunication;
  final Set<HelpNeed> help;
  final String otherHelp;

  /// 주의할 점 (예: 큰 소리에 놀라요).
  final String cautions;

  /// 앓고 있는 병과 먹는 약.
  final String conditions;
  final String allergies;
  final String guardianName;
  final String guardianPhone;

  bool get hasDisability => types.isNotEmpty;

  /// 장애 이름 ('기타'는 입력한 내용).
  List<String> get _disabilityNames => [
        for (final t in DisabilityType.values)
          if (types.contains(t))
            t == DisabilityType.other ? otherDisability.trim() : t.label,
      ].where((s) => s.isNotEmpty).toList();

  /// 의료진에게 보여 줄 문장 (예: 저는 청각장애가 있어요. 글로 써 주세요.).
  List<String> get sentences {
    final disabilities = _disabilityNames;
    return [
      name.trim().isEmpty ? '안녕하세요.' : '안녕하세요. 저는 ${copula(name.trim())}.',
      if (disabilities.isNotEmpty) '저는 ${subjectParticle(disabilities.join(', '))} 있어요.',
      if (severity == Severity.severe) '장애 정도가 심해요.',
      if (severity == Severity.mild) '장애 정도가 심하지 않아요.',
      for (final c in Communication.values)
        if (communication.contains(c)) c.sentence,
      if (otherCommunication.trim().isNotEmpty) otherCommunication.trim(),
      for (final h in HelpNeed.values)
        if (help.contains(h)) h.sentence,
      if (otherHelp.trim().isNotEmpty) otherHelp.trim(),
    ];
  }

  /// 제목을 붙여 보여 줄 내용 (제목, 내용).
  List<(String, String)> get notes => [
        if (cautions.trim().isNotEmpty) ('주의할 점', cautions.trim()),
        if (conditions.trim().isNotEmpty) ('앓고 있는 병·먹는 약', conditions.trim()),
        if (allergies.trim().isNotEmpty) ('알레르기', allergies.trim()),
        if (guardianName.trim().isNotEmpty || guardianPhone.trim().isNotEmpty)
          ('보호자', '${guardianName.trim()} ${guardianPhone.trim()}'.trim()),
      ];

  Map<String, dynamic> toJson() => {
        'name': name,
        'types': [for (final t in types) t.name],
        'otherDisability': otherDisability,
        if (severity != null) 'severity': severity!.name,
        'communication': [for (final c in communication) c.name],
        'otherCommunication': otherCommunication,
        'help': [for (final h in help) h.name],
        'otherHelp': otherHelp,
        'cautions': cautions,
        'conditions': conditions,
        'allergies': allergies,
        'guardianName': guardianName,
        'guardianPhone': guardianPhone,
      };

  /// 앱이 모르는 항목은 건너뛰고 읽는다. 카드는 사용자가 직접 쓴 것이라 하나라도 버리지 않는다.
  factory CareCard.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] as String? ?? '';
    Iterable<String> names(String key) => [...?(json[key] as List?)?.cast<String>()];
    final severity = json['severity'] as String?;
    return CareCard(
      name: text('name'),
      types: {for (final t in names('types')) ?_typeByName[t]},
      otherDisability: text('otherDisability'),
      severity: severity == null ? null : Severity.values.asNameMap()[severity],
      communication: {for (final c in names('communication')) ?_communicationByName[c]},
      otherCommunication: text('otherCommunication'),
      help: {for (final h in names('help')) ?_helpByName[h]},
      otherHelp: text('otherHelp'),
      cautions: text('cautions'),
      conditions: text('conditions'),
      allergies: text('allergies'),
      guardianName: text('guardianName'),
      guardianPhone: text('guardianPhone'),
    );
  }
}
