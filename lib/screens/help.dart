import 'package:flutter/material.dart';

import '../models/hospital.dart';
import '../models/korean.dart';

/// 지정 기관 제도를 쉬운 말로 풀어 쓴 설명.
const categoryHelp = <InstitutionCategory, String>{
  InstitutionCategory.rehabHospital:
      '장애인이 사는 지역 가까이에서 전문 재활 치료를 받을 수 있게 보건복지부가 권역마다 정한 병원이에요. '
          '국립재활원은 나라가 직접 운영하는 재활 전문 기관이에요.',
  InstitutionCategory.rehabDesignated:
      '뇌졸중, 척수 손상, 큰 수술이나 골절 뒤처럼 몸의 기능이 떨어졌을 때, 초기에 집중해서 재활 치료를 하는 병원이에요. '
          '보건복지부가 시설과 인력을 확인하고 지정해요.',
  InstitutionCategory.childRehab:
      '장애가 있는 어린이가 가까운 곳에서 꾸준히 재활 치료를 받을 수 있게 나라와 지방자치단체가 세운 병원과 센터예요.',
  InstitutionCategory.friendlyCheckup:
      '장애인이 건강검진을 편하게 받을 수 있게 휠체어 체중계, 높낮이를 바꾸는 검사대 같은 장비와 '
          '도와줄 사람을 갖춘 검진기관이에요.',
  InstitutionCategory.dentalCenter:
      '일반 치과에서 치료받기 어려운 장애인을 위해 진정 치료나 전신마취 치료 등을 하는 치과 센터예요. '
          '중앙센터와 권역별 센터가 있어요.',
  InstitutionCategory.primaryCare:
      '장애인이 동네 의사 한 명을 주치의로 정해 건강을 꾸준히 관리받는 제도예요. 국민건강보험공단에 등록한 의사가 맡아요. '
          '‘주장애관리’는 장애를, ‘일반건강관리’는 고혈압·당뇨 같은 만성질환을, ‘통합관리’는 둘 다 관리해요.',
  InstitutionCategory.dentalPrimaryCare:
      '장애인이 동네 치과 의사를 주치의로 정해 이와 잇몸을 꾸준히 관리받고 예방 치료를 받는 제도예요.',
  InstitutionCategory.friendlyObgyn:
      '장애가 있는 여성이 임신·출산과 부인과 진료를 편하게 받을 수 있게 높낮이를 바꾸는 진료대 같은 장비와 '
          '도와줄 사람을 갖춘 산부인과예요.',
  InstitutionCategory.mentalHealthCenter:
      '보건복지부에 속한 국립 정신병원과 정신건강 센터예요. 마음의 병을 진료하고 치료해요.',
};

/// '장애인 건강주치의란?' 같은 질문 문구.
String categoryQuestion(InstitutionCategory c) => '${topicQuestion(c.label)}?';

Future<void> showCategoryHelp(BuildContext context, InstitutionCategory c) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(categoryQuestion(c)),
        content: SingleChildScrollView(child: Text(categoryHelp[c]!)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
