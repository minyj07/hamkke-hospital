import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/regions.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/user_profile.dart';
import 'package:hamkke_hospital/services/keywords.dart';
import 'package:hamkke_hospital/services/recommender.dart';

const seoul = Region(code: '110000', name: '서울특별시', lat: 37.5665, lng: 126.978);

Set<String> find(String text) => departmentsFromText(text, departmentNames.values);

void main() {
  group('departmentsFromText', () {
    test('증상 키워드로 진료과를 찾는다', () {
      expect(find('허리 통증'), containsAll(['정형외과', '신경외과', '마취통증의학과']));
      expect(find('아이 발달 검사'), contains('소아청소년과'));
      expect(find('ADHD'), contains('정신건강의학과'));
    });

    test('진료과 이름을 직접 쓰면 그 과를 찾는다 (띄어쓰기 무시)', () {
      expect(find('피부 과 진료'), contains('피부과'));
      expect(find('정형외과'), {'정형외과'});
    });

    test('한 글자 키워드는 다른 낱말 속에 든 경우를 무시한다', () {
      expect(find('귀가 잘 안 들려요'), contains('이비인후과'));
      expect(find('눈'), contains('안과'));
      expect(find('희귀질환'), isEmpty);
      expect(find('폐경'), {'산부인과'});
    });

    test('모르는 말이면 아무것도 찾지 않는다', () {
      expect(find('잘 모르겠어요'), isEmpty);
      expect(find('   '), isEmpty);
    });

    test('키워드 표의 진료과는 모두 실제 데이터의 진료과다', () {
      for (final text in ['척추', '파킨슨', '우울', '보청기', '투석', '욕창', '소변', '임신', '잇몸']) {
        expect(find(text).every(departmentNames.containsValue), isTrue, reason: text);
        expect(find(text), isNotEmpty, reason: text);
      }
    });
  });

  group('기타 직접 입력', () {
    UserProfile profile({
      Set<DisabilityType> types = const {DisabilityType.other},
      String otherDisability = '',
      CareNeed need = CareNeed.other,
      String otherNeed = '',
    }) =>
        UserProfile(
          types: types,
          otherDisability: otherDisability,
          severity: Severity.mild,
          need: need,
          otherNeed: otherNeed,
          region: seoul,
        );

    test('기타 진료에 쓴 내용으로 진료과를 정한다', () {
      final req = buildRequirement(profile(otherNeed: '피부 질환'));
      expect(req.departments, {'피부과'});
      expect(req.unmatchedTexts, isEmpty);
    });

    test('기타 장애에 쓴 내용은 일반 진료의 진료과에 더해진다', () {
      final req = buildRequirement(profile(
        otherDisability: '척수손상',
        need: CareNeed.general,
      ));
      expect(req.departments, containsAll(['재활의학과', '신경외과', '가정의학과']));
    });

    test('맞는 진료과를 못 찾으면 일반 진료로 찾고 그 글을 알려준다', () {
      final req = buildRequirement(profile(otherDisability: '희귀질환', otherNeed: '잘 모르겠음'));
      expect(req.departments, {'가정의학과', '내과'});
      expect(req.unmatchedTexts, ['희귀질환', '잘 모르겠음']);
    });

    test('화면에는 기타와 입력한 내용을 함께 보여준다', () {
      final p = profile(
        types: {DisabilityType.visual, DisabilityType.other},
        otherDisability: '척수손상',
        otherNeed: '피부 질환',
      );
      expect(p.typesLabel, '시각장애, 기타(척수손상)');
      expect(p.needLabel, '기타(피부 질환)');
    });
  });
}
