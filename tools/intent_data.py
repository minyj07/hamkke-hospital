"""메디움 AI 학습 데이터: 말하듯 적은 문장과 그 정답을 만든다.

정답은 병원 찾기 조건과 같다: 장애 유형(여러 개), 진료 목적(하나), 장애 정도, 어린이인지,
꼭 필요한 편의시설(여러 개), 진료과(여러 개). 이름은 앱의 enum 이름과 같아야 한다
(lib/models/disability.dart, lib/models/hospital.dart). tools/test_intent.py 가 검사한다.

표현 목록은 직접 만들었다. 공공데이터에는 이런 문장이 없어서, 장애 유형·진료·편의시설을
사람들이 말하는 여러 방식으로 적고 틀(template)에 넣어 문장을 만든다.
학습용과 평가용은 표현 단위로 나눠서, 평가 문장에는 학습 때 못 본 표현이 들어간다.

정답을 붙이는 규칙:
- 편의시설은 글에 드러난 것만 붙인다. 앱이 장애 유형으로 미리 고르는 시설은 따로 붙인다.
- '휠체어를 타요'는 지체장애 + 휠체어 접근, '휠체어로 들어갈 수 있는'은 휠체어 접근만이다.
- 수어 통역은 청각장애, 투석·인공신장실은 신장장애, 장루·요루는 장애인 화장실도 붙인다.
- '발달장애'는 지적장애와 자폐성장애 둘 다다.
- 진료 목적이 7가지에 없고 진료과가 드러나면(피부가 가려워요) 'other' 와 그 진료과다.
  내과·가정의학과·소아청소년과처럼 아플 때 가는 과는 'general' 이다.
- 진료 목적이 드러나지 않으면 'none' 이다. 앱은 그때 진료를 고르게 한다.
- 조건이 하나도 없는 글(인사, 앱에 대한 말, 아무 뜻 없는 글자)은 모두 비워 둔다.
"""

import random

TYPES = ["physical", "brainLesion", "visual", "hearing", "speech", "intellectual", "autism",
         "mental", "kidney", "heart", "respiratory", "liver", "facial", "ostomy", "epilepsy"]
NEEDS = ["general", "rehab", "checkup", "dental", "chronic", "pregnancy", "mentalHealth",
         "other", "none"]
SEVERITIES = ["severe", "mild", "none"]
FACILITIES = ["wheelchair", "parking", "toilet", "lift", "signLanguage", "braille", "sedation",
              "quietRoom", "dialysis"]
DEPARTMENTS = ["내과", "신경과", "정신건강의학과", "외과", "정형외과", "신경외과", "성형외과",
               "마취통증의학과", "산부인과", "소아청소년과", "안과", "이비인후과", "피부과",
               "비뇨의학과", "재활의학과", "가정의학과", "치과"]


class Phrase:
    """같은 뜻의 여러 표현. forms 는 문장 속 자리별 표현이다.

    adn: 꾸미는 말 ('휠체어 타는' 아버지), conn: 이어지는 말 (휠체어를 '타는데'),
    clause: 문장 ('휠체어를 타요'), noun: 낱말 ('휠체어'), purpose: '재활 치료 받을' 병원,
    req: '수어 통역 되는' 병원, np: '아버지가', pre/post: 정도 낱말 ('중증' 지체장애, 지체장애 '1급').
    """

    def __init__(self, types=(), need=None, severity=None, child=False, facilities=(),
                 departments=(), **forms):
        self.types = set(types)
        self.need = need
        self.severity = severity
        self.child = child
        self.facilities = set(facilities)
        self.departments = set(departments)
        self.forms = {k: list(v) for k, v in forms.items()}
        self.split = {}

    def make_split(self, rng: random.Random, test_share: float):
        """표현을 학습용·평가용으로 나눈다. 표현이 하나뿐이면 둘 다 쓴다."""
        for form, items in self.forms.items():
            shuffled = items[:]
            rng.shuffle(shuffled)
            n_test = max(1, round(len(shuffled) * test_share)) if len(shuffled) >= 3 else 0
            test, train = shuffled[:n_test], shuffled[n_test:]
            self.split[form] = {"train": train, "test": test or train}

    def pick(self, rng: random.Random, form: str, split: str):
        """split 은 'train', 'test' 또는 둘 다인 'all'."""
        options = self.forms.get(form) if split == "all" else self.split.get(form, {}).get(split)
        return rng.choice(options) if options else None

    def has(self, form: str) -> bool:
        return bool(self.forms.get(form))


# ---- 장애 ----

DISABILITIES = [
    Phrase(types={"physical"}, facilities={"wheelchair"},
           adn=["휠체어 타는", "휠체어를 타는", "휠체어 쓰는", "휠체어를 사용하는", "전동휠체어 타는",
                "휠체어 생활하는", "휠체어에 앉아 지내는", "휠체어 타시는", "휠체어 쓰시는"],
           conn=["휠체어를 타는데", "휠체어를 타서", "휠체어를 쓰는데", "휠체어 생활을 해서",
                 "전동휠체어를 타서", "휠체어로 다녀서", "휠체어를 타고 다녀서", "휠체어를 타시는데", "휠체어를 타셔서"],
           clause=["휠체어를 타요", "휠체어를 써요", "휠체어로 다녀요", "전동휠체어를 타요",
                   "휠체어 생활을 해요", "휠체어를 사용해요", "휠체어를 타세요", "휠체어를 쓰세요"],
           noun=["휠체어", "휠체어 사용자", "휠체어 이용자", "전동휠체어", "휠체어 장애인",
                 "휠체어 사용"]),
    Phrase(types={"physical"},
           adn=["다리가 불편한", "거동이 불편한", "걷기 힘든", "잘 못 걷는", "보행이 어려운",
                "다리를 저는", "몸이 불편한", "팔다리가 불편한", "혼자 못 걷는", "다리가 불편하신", "거동이 불편하신", "잘 못 걸으시는", "걷기 힘드신"],
           conn=["다리가 불편해서", "거동이 불편한데", "잘 못 걸어서", "걷는 게 힘들어서",
                 "보행이 어려워서", "다리를 절어서", "몸이 불편해서", "혼자서는 못 걸어서", "다리가 불편하셔서", "거동이 불편하신데", "잘 못 걸으셔서", "걷지 못하셔서"],
           clause=["다리가 불편해요", "거동이 불편해요", "잘 못 걸어요", "걷기가 힘들어요",
                   "혼자 못 걸어요", "보행 보조기를 써요", "다리를 절어요", "다리가 불편하세요", "거동이 불편하세요", "걷기 힘드세요", "잘 못 걸으세요"],
           noun=["거동 불편", "보행 장애", "하지 장애", "보행 불편", "다리 장애"]),
    Phrase(types={"physical"},
           adn=["하반신 마비가 있는", "척수를 다친", "척수장애가 있는", "사지마비가 있는",
                "하반신을 못 쓰는", "척수 손상을 입은"],
           conn=["하반신 마비라서", "척수를 다쳐서", "척수장애가 있는데", "사지마비라서",
                 "하반신을 못 써서", "척수 손상으로"],
           clause=["하반신 마비가 있어요", "척수장애가 있어요", "척수를 다쳤어요", "사지마비예요",
                   "하반신을 못 써요"],
           noun=["하반신 마비", "척수장애", "척수 손상", "사지마비", "척수 장애", "척수손상",
                 "하반신마비"]),
    Phrase(types={"physical"},
           adn=["다리를 절단한", "의족을 쓰는", "목발 짚는", "한쪽 팔이 없는", "의수를 쓰는",
                "소아마비가 있는", "관절이 굳은"],
           conn=["다리를 절단해서", "의족을 써서", "목발을 짚어서", "팔을 절단해서",
                 "소아마비가 있어서", "관절이 굳어서"],
           clause=["다리를 절단했어요", "의족을 써요", "목발을 짚어요", "소아마비가 있어요",
                   "한쪽 팔이 불편해요", "관절이 굳었어요"],
           noun=["절단 장애", "의족", "목발", "소아마비", "의수", "절단"]),
    Phrase(types={"physical"},
           adn=["지체장애가 있는", "지체장애인인", "지체장애를 가진"],
           conn=["지체장애가 있는데", "지체장애인이라서", "지체장애가 있어서"],
           clause=["지체장애가 있어요", "지체장애인이에요", "지체장애 판정을 받았어요"],
           noun=["지체장애", "지체장애인", "지체", "지체 장애", "지체장애자"]),
    Phrase(types={"brainLesion"},
           adn=["뇌성마비가 있는", "뇌병변장애가 있는", "편마비가 있는", "중풍으로 마비가 온",
                "뇌졸중 후유증이 있는", "뇌출혈로 쓰러졌던", "뇌경색을 앓은", "뇌손상을 입은",
                "한쪽 몸이 마비된", "중풍 맞으신", "뇌졸중으로 쓰러지셨던", "편마비가 오신"],
           conn=["뇌성마비라서", "뇌병변장애가 있는데", "편마비가 와서", "중풍으로 쓰러지셔서",
                 "뇌졸중 후유증이 있어서", "뇌출혈 이후로", "뇌경색 후유증으로", "뇌를 다쳐서",
                 "한쪽 몸이 마비돼서", "뇌경색이 오셔서", "중풍으로 쓰러지신 뒤로", "편마비가 오셔서"],
           clause=["뇌성마비가 있어요", "뇌병변장애가 있어요", "편마비가 왔어요",
                   "중풍으로 한쪽이 마비됐어요", "뇌졸중으로 쓰러지셨어요", "뇌출혈 후유증이 있어요",
                   "뇌경색이 왔었어요", "뇌경색이 오셨어요", "편마비가 오셨어요"],
           noun=["뇌성마비", "뇌병변장애", "뇌병변", "편마비", "뇌졸중 후유증", "중풍", "뇌출혈 후유증",
                 "뇌경색", "뇌손상", "뇌병변 장애", "뇌졸중"]),
    Phrase(types={"visual"},
           adn=["앞이 안 보이는", "눈이 안 보이는", "시각장애가 있는", "시력을 잃은", "저시력인",
                "앞을 못 보는", "실명한", "눈이 거의 안 보이는", "안내견과 다니는", "흰 지팡이를 쓰는", "눈이 안 보이시는", "앞이 잘 안 보이시는"],
           conn=["앞이 안 보여서", "눈이 안 보이는데", "시각장애가 있어서", "실명해서",
                 "시력이 거의 없어서", "앞을 못 봐서", "시각장애인이라", "눈이 잘 안 보여서", "눈이 잘 안 보이셔서", "앞이 안 보이셔서"],
           clause=["앞이 안 보여요", "눈이 안 보여요", "시각장애가 있어요", "시각장애인이에요",
                   "시력을 잃었어요", "저시력이에요", "앞을 못 봐요", "눈이 거의 안 보여요", "눈이 잘 안 보이세요"],
           noun=["시각장애", "시각장애인", "저시력", "전맹", "실명", "시각 장애", "맹인", "시각"]),
    Phrase(types={"hearing"},
           adn=["귀가 안 들리는", "청각장애가 있는", "소리를 못 듣는", "보청기 끼는", "인공와우를 한",
                "잘 못 듣는", "난청이 있는", "귀가 어두운", "청력이 나쁜", "귀가 어두우신", "잘 못 들으시는", "귀가 안 들리시는"],
           conn=["귀가 안 들려서", "청각장애가 있는데", "잘 못 들어서", "난청이 심해서",
                 "보청기를 껴도 잘 안 들려서", "소리를 못 들어서", "귀가 어두워서", "청력이 없어서", "귀가 어두우셔서", "잘 못 들으셔서", "보청기를 끼셔서"],
           clause=["귀가 안 들려요", "청각장애가 있어요", "청각장애인이에요", "잘 못 들어요",
                   "난청이 있어요", "보청기를 껴요", "인공와우를 했어요", "귀가 잘 안 들려요", "귀가 어두우세요", "잘 못 들으세요"],
           noun=["청각장애", "청각장애인", "난청", "보청기", "인공와우", "청각 장애", "청력 손실",
                 "청각"]),
    Phrase(types={"hearing"}, facilities={"signLanguage"},
           adn=["수어를 쓰는", "수어로 대화하는", "농인인", "농아인인"],
           conn=["수어로만 대화해서", "수어를 써서", "농인이라서", "수어만 할 줄 알아서"],
           clause=["수어를 써요", "수어로 대화해요", "농인이에요", "수어만 할 줄 알아요"],
           noun=["수어 사용자", "농아인", "농인", "수어 쓰는 사람"]),
    Phrase(types={"speech"},
           adn=["말을 잘 못하는", "말하기 어려운", "언어장애가 있는", "말을 더듬는", "발음이 어눌한",
                "말이 잘 안 나오는", "목소리를 못 내는", "말씀을 잘 못하시는"],
           conn=["말을 잘 못해서", "말하기가 어려워서", "언어장애가 있는데", "실어증이 있어서",
                 "말이 잘 안 나와서", "말을 더듬어서", "발음이 어눌해서", "말씀을 잘 못하셔서"],
           clause=["말을 잘 못해요", "말하기가 어려워요", "언어장애가 있어요", "실어증이 있어요",
                   "말을 더듬어요", "발음이 어눌해요", "말이 잘 안 나와요"],
           noun=["언어장애", "실어증", "구음장애", "말더듬", "언어 장애", "말 장애", "음성 장애"]),
    Phrase(types={"intellectual"},
           adn=["지적장애가 있는", "지적 장애인", "인지가 낮은", "이해가 느린", "지적 능력이 낮은",
                "다운증후군이 있는"],
           conn=["지적장애가 있어서", "지적장애라서", "이해하는 게 느려서", "인지 능력이 낮아서",
                 "다운증후군이라서"],
           clause=["지적장애가 있어요", "지적장애인이에요", "이해가 느려요", "다운증후군이 있어요",
                   "인지 능력이 낮아요"],
           noun=["지적장애", "지적 장애", "인지 장애", "지적장애인", "다운증후군", "지능 장애"]),
    Phrase(types={"autism"},
           adn=["자폐가 있는", "자폐성장애가 있는", "자폐 스펙트럼인", "자폐 성향이 있는",
                "아스퍼거가 있는"],
           conn=["자폐가 있어서", "자폐라서", "자폐 스펙트럼이라서", "자폐성장애가 있는데",
                 "자폐 성향이 있어서"],
           clause=["자폐가 있어요", "자폐성장애가 있어요", "자폐 스펙트럼이에요", "자폐 진단을 받았어요"],
           noun=["자폐", "자폐성장애", "자폐 스펙트럼", "아스퍼거", "자폐증", "자폐성 장애"]),
    Phrase(types={"intellectual", "autism"},
           adn=["발달장애가 있는", "발달이 느린", "발달장애인인"],
           conn=["발달장애가 있어서", "발달장애라서", "발달이 느려서"],
           clause=["발달장애가 있어요", "발달이 느려요", "발달장애인이에요"],
           noun=["발달장애", "발달 장애", "발달장애인"]),
    Phrase(types={"mental"},
           adn=["조현병이 있는", "정신장애가 있는", "양극성 장애가 있는", "조울증이 있는",
                "정신질환을 앓는", "조현병을 앓는"],
           conn=["조현병이 있어서", "정신장애가 있는데", "조울증이라서", "정신질환이 있어서",
                 "양극성 장애라서"],
           clause=["조현병이 있어요", "정신장애가 있어요", "조울증이 있어요", "정신질환을 앓고 있어요"],
           noun=["정신장애", "조현병", "양극성 장애", "조울증", "정신질환", "정신 장애"]),
    Phrase(types={"kidney"}, facilities={"dialysis"},
           adn=["투석 받는", "혈액투석 하는", "투석 중인", "복막투석 하는", "투석 받으시는"],
           conn=["투석을 받아서", "투석 중이라", "일주일에 세 번 투석해서", "혈액투석을 해서", "투석을 받으셔서"],
           clause=["투석을 받아요", "혈액투석을 해요", "투석 중이에요", "복막투석을 해요", "투석을 받으세요"],
           noun=["투석", "혈액투석", "복막투석", "투석 환자"]),
    Phrase(types={"kidney"},
           adn=["신장장애가 있는", "콩팥이 안 좋은", "신부전이 있는", "신장 이식을 받은"],
           conn=["신장이 안 좋아서", "신부전이 있어서", "신장장애가 있는데", "콩팥이 나빠서",
                 "신장 이식을 받아서"],
           clause=["신장장애가 있어요", "신부전이 있어요", "콩팥이 안 좋아요", "신장 이식을 받았어요"],
           noun=["신장장애", "신부전", "콩팥병", "신장 이식", "신장 장애", "만성 신부전"]),
    Phrase(types={"heart"},
           adn=["심장이 안 좋은", "심장장애가 있는", "심부전이 있는", "심장 수술을 받은", "심장병이 있는", "심장 수술을 받으신"],
           conn=["심장이 약해서", "심장 수술을 받아서", "심부전이 있어서", "심장장애가 있는데",
                 "심장병이 있어서", "심장이 안 좋으셔서"],
           clause=["심장이 안 좋아요", "심장장애가 있어요", "심부전이 있어요", "심장 수술을 받았어요"],
           noun=["심장장애", "심부전", "심장병", "심장 장애", "심장 질환", "선천성 심장병"]),
    Phrase(types={"respiratory"},
           adn=["숨쉬기 힘든", "호흡기장애가 있는", "산소통 쓰는", "산소 치료 받는", "폐가 안 좋은", "산소통 쓰시는", "숨이 차신"],
           conn=["숨이 차서", "산소통을 달고 있어서", "폐가 안 좋아서", "호흡기장애가 있는데",
                 "숨쉬기가 힘들어서", "숨이 차셔서", "산소를 달고 계셔서"],
           clause=["숨이 차요", "숨쉬기가 힘들어요", "호흡기장애가 있어요", "산소통을 써요",
                   "폐가 안 좋아요", "숨이 차세요"],
           noun=["호흡기장애", "만성 폐쇄성 폐질환", "copd", "산소통", "인공호흡기", "호흡기 장애",
                 "폐섬유화"]),
    Phrase(types={"liver"},
           adn=["간이 안 좋은", "간경화가 있는", "간장애가 있는", "간 이식을 받은", "간경변이 있는"],
           conn=["간경화라서", "간 이식을 받아서", "간이 안 좋아서", "간장애가 있는데",
                 "간경변이 있어서", "간이 안 좋으셔서"],
           clause=["간이 안 좋아요", "간경화가 있어요", "간장애가 있어요", "간 이식을 받았어요"],
           noun=["간장애", "간경화", "간 이식", "간경변", "간 장애", "간 질환"]),
    Phrase(types={"facial"},
           adn=["얼굴에 화상 흉터가 있는", "안면장애가 있는", "얼굴에 큰 흉터가 있는",
                "안면 변형이 있는"],
           conn=["얼굴에 화상을 입어서", "안면장애가 있어서", "얼굴에 흉터가 있어서"],
           clause=["얼굴에 화상 흉터가 있어요", "안면장애가 있어요", "얼굴이 변형됐어요"],
           noun=["안면장애", "안면 변형", "얼굴 화상", "안면 장애", "얼굴 기형"]),
    Phrase(types={"ostomy"}, facilities={"toilet"},
           adn=["장루 주머니를 찬", "장루가 있는", "요루가 있는", "배변 주머니를 차는", "인공항문을 단"],
           conn=["장루를 달고 있어서", "요루가 있어서", "배변 주머니를 차서", "장루 수술을 받아서"],
           clause=["장루가 있어요", "요루가 있어요", "배변 주머니를 차요", "장루 수술을 받았어요"],
           noun=["장루", "요루", "장루 요루", "인공항문", "배변 주머니", "장루장애", "요루장애"]),
    Phrase(types={"epilepsy"},
           adn=["뇌전증이 있는", "발작을 하는", "간질이 있는", "경련을 하는", "뇌전증을 앓는"],
           conn=["뇌전증이 있어서", "발작이 자주 있어서", "간질이 있는데", "경련을 해서", "뇌전증이라서"],
           clause=["뇌전증이 있어요", "발작을 해요", "간질이 있어요", "경련을 자주 해요"],
           noun=["뇌전증", "간질", "뇌전증장애", "경련 발작", "뇌전증 장애", "발작"]),
    # 장애가 있다는 것만 말하고 유형은 말하지 않은 경우.
    Phrase(adn=["장애가 있는", "장애인인", "장애를 가진"],
           conn=["장애가 있어서", "장애인이라서", "장애가 있는데"],
           clause=["장애가 있어요", "장애인이에요", "장애 판정을 받았어요"],
           noun=["장애인", "장애", "장애가 있는 사람"]),
]

SEVERITY = [
    Phrase(severity="severe",
           clause=["장애 정도가 심해요", "중증이에요", "장애가 심한 편이에요", "1급이에요", "2급이에요",
                   "3급이에요", "중증 장애인이에요", "심한 장애예요"],
           pre=["중증", "심한", "장애 정도가 심한", "중증의"],
           post=["1급", "2급", "3급", "중증"],
           after=["심해서", "심한데", "심하고", "많이 심해요", "심한 편이라", "중증이라", "심하셔서",
                  "심하세요"]),
    Phrase(severity="mild",
           clause=["장애 정도가 심하지 않아요", "경증이에요", "심하지 않은 편이에요", "4급이에요",
                   "5급이에요", "6급이에요", "장애가 가벼운 편이에요"],
           pre=["경증", "심하지 않은", "가벼운", "경증의"],
           post=["4급", "5급", "6급", "경증"],
           after=["심하지 않아서", "가벼운데", "가벼운 편이라", "심하지 않은데", "경증이라", "가벼워요",
                  "심하진 않아요", "가벼우셔서"]),
]

# ---- 진료 ----

NEEDS_PHRASES = [
    Phrase(need="general",
           purpose=["진료받을", "아플 때 갈", "진찰받을", "감기 진료 볼", "몸살 나서 갈", "열 나서 갈",
                    "동네에서 다닐", "일반 진료 볼", "독감 검사 받을"],
           clause=["감기에 걸렸어요", "열이 나요", "몸이 안 좋아요", "아파요", "기침이 나요",
                   "몸살이 났어요", "목감기에 걸렸어요", "독감 같아요", "예방접종을 맞아야 해요"],
           noun=["감기", "일반 진료", "진료", "몸살", "독감", "기침", "예방접종", "열"]),
    Phrase(need="general", departments={"내과"},
           purpose=["내과 진료 볼", "소화 문제로 갈", "배가 아파서 갈"],
           clause=["배가 아파요", "소화가 안 돼요", "속이 쓰려요", "장염 같아요", "설사를 해요"],
           noun=["내과", "소화불량", "장염", "복통", "위염"]),
    Phrase(need="general", departments={"소아청소년과"}, child=True,
           purpose=["소아과 진료 볼", "소아과 다닐"],
           clause=["소아과에 가야 해요"],
           noun=["소아과", "소아청소년과", "어린이 병원"]),
    Phrase(need="general", departments={"가정의학과"},
           purpose=["가정의학과 진료 볼"], noun=["가정의학과", "동네 의원"]),
    Phrase(need="rehab", departments={"재활의학과"},
           purpose=["재활 치료 받을", "물리치료 받을", "재활받을", "걷는 연습 할", "작업치료 받을",
                    "운동치료 받을", "재활 입원할", "재활 운동 할"],
           clause=["재활 치료가 필요해요", "물리치료를 받아야 해요", "재활을 하고 싶어요",
                   "재활 운동이 필요해요", "걷는 연습을 해야 해요", "재활 치료를 받고 싶어요"],
           noun=["재활", "재활 치료", "물리치료", "작업치료", "재활병원", "운동치료", "재활의학과",
                 "재활 입원", "도수치료"]),
    Phrase(need="rehab", departments={"재활의학과"},
           purpose=["언어치료 받을", "말하기 치료 받을", "삼킴 치료 받을"],
           clause=["언어치료가 필요해요", "말하기 연습을 해야 해요", "삼키는 게 힘들어요"],
           noun=["언어치료", "언어 재활", "삼킴 재활"]),
    Phrase(need="checkup",
           purpose=["건강검진 받을", "검진받을", "국가검진 받을", "종합검진 할", "암 검진 받을",
                    "건강 검진할", "내시경 검사 받을"],
           clause=["건강검진을 받고 싶어요", "검진 받아야 해요", "국가건강검진 대상이에요",
                   "건강검진 할 때가 됐어요", "종합검진을 해 보고 싶어요", "내시경을 받아야 해요"],
           noun=["건강검진", "국가검진", "검진", "종합검진", "암 검진", "건강 검진", "국가건강검진",
                 "내시경"]),
    Phrase(need="dental", departments={"치과"},
           purpose=["치과 치료 받을", "충치 치료할", "스케일링 받을", "이 치료할", "이를 뽑을",
                    "잇몸 치료 받을", "신경 치료 받을", "임플란트 할"],
           clause=["이가 아파요", "충치가 생겼어요", "잇몸에서 피가 나요", "이가 흔들려요",
                   "치과 치료가 필요해요", "이가 깨졌어요", "사랑니가 아파요", "이가 시려요"],
           noun=["치과", "충치", "스케일링", "치아 치료", "임플란트", "사랑니", "잇몸", "치과 진료",
                 "장애인 치과", "치아"]),
    Phrase(need="chronic", departments={"내과"},
           purpose=["당뇨 관리할", "혈압 관리할", "혈당 관리할", "고지혈증 약 받을"],
           clause=["당뇨가 있어요", "고혈압이 있어요", "혈압이 높아요", "혈당 관리가 필요해요",
                   "콜레스테롤이 높아요"],
           noun=["당뇨", "고혈압", "고지혈증", "혈압", "당뇨병", "혈당"]),
    Phrase(need="chronic",
           purpose=["꾸준히 다닐", "정기적으로 다닐", "만성질환 관리할", "약 처방받으러 다닐",
                    "계속 다닐", "오래 다닐", "주치의로 다닐"],
           clause=["꾸준히 관리받고 싶어요", "약을 계속 먹어야 해요", "정기적으로 진료받아야 해요",
                   "주치의가 필요해요"],
           noun=["만성질환", "주치의", "건강 관리", "장애인 건강주치의", "만성 질환", "정기 진료"]),
    Phrase(need="pregnancy", departments={"산부인과"},
           purpose=["출산할", "산전 검사 받을", "임신 중에 다닐", "아기 낳을", "분만할", "임신 검사 받을"],
           clause=["임신했어요", "임신 중이에요", "출산 예정이에요", "아기를 가졌어요", "곧 출산해요"],
           noun=["임신", "출산", "산부인과", "산전 검사", "분만", "임산부", "산모"]),
    Phrase(need="mentalHealth", departments={"정신건강의학과"},
           purpose=["상담받을", "마음 치료 받을", "정신과 진료 볼", "심리 상담 받을", "정신건강의학과 다닐"],
           clause=["마음이 힘들어요", "우울해요", "불안이 심해요", "잠을 못 자요", "스트레스가 심해요",
                   "공황이 와요", "너무 우울해요"],
           noun=["정신과", "심리 상담", "우울증", "불안", "마음 건강", "정신건강의학과", "공황장애",
                 "상담", "불면증"]),
    Phrase(need="other", departments={"피부과"},
           purpose=["피부 진료 볼", "피부 치료 받을"],
           clause=["피부가 가려워요", "두드러기가 났어요", "피부에 뭐가 났어요", "습진이 생겼어요"],
           noun=["피부과", "아토피", "습진", "두드러기", "피부"]),
    Phrase(need="other", departments={"안과"},
           purpose=["눈 검사 받을", "안과 진료 볼", "백내장 수술 받을"],
           clause=["눈이 침침해요", "눈이 아파요", "눈이 충혈됐어요", "눈이 뿌옇게 보여요"],
           noun=["안과", "백내장", "녹내장", "눈 검사", "시력 검사"]),
    Phrase(need="other", departments={"이비인후과"},
           purpose=["이비인후과 진료 볼", "귀 검사 받을", "청력 검사 받을"],
           clause=["귀가 아파요", "코가 막혀요", "목이 아파요", "이명이 있어요", "귀에서 소리가 나요"],
           noun=["이비인후과", "비염", "중이염", "이명", "귀 검사", "청력 검사"]),
    Phrase(need="other", departments={"정형외과"},
           purpose=["관절 치료할", "무릎 치료 받을", "어깨 치료 받을", "골절 치료 받을"],
           clause=["무릎이 아파요", "어깨가 아파요", "넘어져서 다쳤어요", "뼈가 부러진 것 같아요",
                   "손목을 삐었어요", "발목을 접질렸어요"],
           noun=["정형외과", "관절", "골절", "무릎 통증", "어깨 통증", "관절염"]),
    Phrase(need="other", departments={"정형외과", "신경외과", "마취통증의학과"},
           purpose=["허리 치료 받을", "디스크 치료할"],
           clause=["허리가 아파요", "허리 디스크가 있어요", "허리가 너무 아파요"],
           noun=["허리 디스크", "디스크", "허리 통증", "척추 질환"]),
    Phrase(need="other", departments={"비뇨의학과"},
           purpose=["비뇨기 진료 볼", "소변 검사 받을"],
           clause=["소변보기가 힘들어요", "소변을 자주 봐요", "방광이 안 좋아요", "소변이 안 나와요"],
           noun=["비뇨기과", "비뇨의학과", "배뇨 장애", "방광", "전립선"]),
    Phrase(need="other", departments={"신경과"},
           purpose=["신경과 진료 볼", "뇌파 검사 받을", "치매 검사 받을"],
           clause=["두통이 심해요", "어지러워요", "손이 떨려요", "기억력이 떨어졌어요", "머리가 아파요"],
           noun=["신경과", "두통", "치매", "파킨슨", "어지럼증", "뇌파 검사", "편두통"]),
    Phrase(need="other", departments={"외과"},
           purpose=["상처 치료 받을", "외과 진료 볼"],
           clause=["상처가 났어요", "혹이 만져져요", "상처가 덧났어요"],
           noun=["외과", "상처 치료", "혹"]),
    Phrase(need="other", departments={"성형외과", "피부과", "외과"},
           purpose=["욕창 치료 받을", "욕창 소독할"],
           clause=["욕창이 생겼어요", "욕창이 심해요"],
           noun=["욕창", "욕창 치료"]),
    Phrase(need="other", departments={"성형외과"},
           purpose=["흉터 치료 받을", "성형외과 진료 볼"],
           clause=["흉터가 심해요", "흉터를 치료하고 싶어요"],
           noun=["성형외과", "흉터", "흉터 치료"]),
    Phrase(need="other", departments={"마취통증의학과"},
           purpose=["통증 치료 받을", "주사 치료 받을"],
           clause=["통증이 심해요", "온몸이 쑤셔요", "만성 통증이 있어요"],
           noun=["통증 클리닉", "마취통증의학과", "만성 통증"]),
    Phrase(need="other", departments={"신경외과"},
           purpose=["신경외과 진료 볼"],
           clause=["목 디스크가 있어요"],
           noun=["신경외과", "목 디스크"]),
]

# 진료 목적이 드러나지 않는 끝말.
NO_NEED_PLACES = ["갈 병원", "갈 만한 곳", "다닐 병원", "갈 수 있는 병원", "병원", "곳", "갈 곳",
                  "가 볼 병원", "찾아갈 병원"]

# ---- 편의시설 ----

FACILITY_PHRASES = [
    Phrase(facilities={"wheelchair"},
           req=["휠체어로 들어갈 수 있는", "휠체어 접근 가능한", "휠체어 타고 갈 수 있는", "경사로 있는",
                "턱이 없는", "엘리베이터 있는", "휠체어로 다닐 수 있는", "문턱 없는", "휠체어가 들어가는", "휠체어 되는", "휠체어 출입 가능한"],
           noun=["휠체어 접근", "경사로", "엘리베이터", "휠체어 출입", "휠체어 진입"],
           clause=["휠체어로 들어갈 수 있어야 해요", "엘리베이터가 있어야 해요", "턱이 없어야 해요"]),
    Phrase(facilities={"parking"},
           req=["장애인 주차 되는", "주차할 수 있는", "장애인 주차장 있는", "차 가지고 갈 수 있는",
                "주차장 넓은", "주차 가능한", "주차되는"],
           noun=["장애인 주차", "주차장", "장애인 주차구역", "주차"],
           clause=["차를 가지고 가요", "주차가 돼야 해요", "주차가 꼭 필요해요"]),
    Phrase(facilities={"toilet"},
           req=["장애인 화장실 있는", "화장실이 넓은", "장애인 화장실이 있는", "장애인 화장실 되는"],
           noun=["장애인 화장실", "장애인화장실"],
           clause=["장애인 화장실이 꼭 있어야 해요", "화장실 문제가 걱정돼요"]),
    Phrase(facilities={"lift"},
           req=["리프트 있는", "전동 검사대 있는", "침대로 옮기기 쉬운", "이동식 리프트 있는",
                "높낮이 조절되는 검사대 있는", "리프트 되는"],
           noun=["리프트", "전동 검사대", "이동식 리프트", "높낮이 조절 검사대"],
           clause=["검사대로 옮겨 앉기 힘들어요", "리프트가 필요해요", "혼자 침대에 못 올라가요"]),
    Phrase(types={"hearing"}, facilities={"signLanguage"},
           req=["수어 통역 되는", "수어 가능한", "수어로 진료하는", "수어 통역사가 있는",
                "수어 통역 지원되는", "수어 되는", "통역 되는"],
           noun=["수어 통역", "수어통역", "수어 통역사"],
           clause=["수어 통역이 필요해요", "수어 통역을 받고 싶어요"]),
    Phrase(facilities={"braille"},
           req=["점자 안내 있는", "음성 안내 되는", "점자 블록 있는", "점자 안내판 있는", "음성 안내 가능한", "점자 되는"],
           noun=["점자 안내", "음성 안내", "점자", "점자 블록"],
           clause=["음성 안내가 필요해요", "점자 안내가 있어야 해요"]),
    Phrase(facilities={"sedation"},
           req=["수면 치료 되는", "진정 치료 가능한", "재워서 치료하는", "마취하고 치료하는",
                "수면 마취 되는"],
           noun=["수면 치료", "진정 치료", "수면 마취", "전신 마취"],
           clause=["수면 치료를 해야 해요", "마취하고 치료해야 해요", "진정 치료가 필요해요"]),
    Phrase(facilities={"quietRoom"},
           req=["조용히 기다릴 수 있는", "대기실이 조용한", "덜 기다리는", "따로 기다릴 수 있는", "조용한 대기실 있는"],
           noun=["조용한 대기실", "조용한 곳", "독립 대기실"],
           clause=["시끄러운 곳을 힘들어해요", "오래 기다리면 힘들어해요", "사람 많은 곳을 무서워해요",
                   "소리에 예민해요", "오래 못 기다려요"]),
    Phrase(types={"kidney"}, facilities={"dialysis"},
           req=["투석 되는", "인공신장실 있는", "혈액투석 할 수 있는", "투석실 있는"],
           noun=["인공신장실", "투석실"],
           clause=["투석을 해야 해요", "투석할 곳이 필요해요"]),
]

# ---- 조건이 없는 글 ----

# 병원 찾기 조건이 드러나지 않는 글: 인사, 앱에 대한 말, 조건 없이 병원만 찾는 말. 정답은 모두 비어 있다.
# 첫 앱 모델은 이런 글을 배운 적이 없어서 '안녕하세요'에도 장애를 골라냈다.
CHATTER = ["안녕하세요", "안녕", "감사합니다", "고맙습니다", "네", "아니요", "잘 모르겠어요", "모르겠어요",
           "테스트", "테스트입니다", "오늘 날씨 어때요", "밥 먹었어요", "반가워요", "궁금한 게 있어요",
           "질문이 있어요", "음", "hello", "hi", "test", "1234", "앱 어떻게 써요", "뭐라고 쓰면 돼요",
           "좋은 하루 보내세요", "수고하세요", "여보세요", "저기요", "아무거나", "그냥", "가나다라", "asdf",
           "오늘", "내일", "주말에", "지금 바로", "빨리요", "급해요", "병원 찾아요", "병원 추천해 주세요",
           "근처 병원", "가까운 병원", "좋은 병원", "큰 병원", "종합병원", "대학병원", "동네 병원", "의원",
           "병원 어디 있어요", "진료 시간 알려 주세요", "예약하고 싶어요", "전화번호 알려 주세요",
           "가격이 얼마예요", "친절한 병원", "잘하는 병원", "유명한 병원", "새로 생긴 병원",
           "밤에 여는 병원", "주말에 여는 병원", "오늘 문 여는 병원", "어떻게 하면 돼요", "이거 뭐예요",
           "처음이에요", "잘 부탁해요", "확인", "취소", "다시", "좋아요", "싫어요", "배고파요", "졸려요",
           # 두 번째 보강 (조정용 '조건 없는 글'에서 장애·기타 진료를 잘못 골라내서 더했다)
           "사용법 알려 주세요", "어떻게 검색해요", "글을 어떻게 써요", "이 앱 좋네요", "업데이트 했어요",
           "설정은 어디 있어요", "잘 안 돼요", "오류가 나요", "화면이 안 나와요", "느려요", "고장 났어요",
           "비가 와요", "춥네요", "덥네요", "주말 잘 보내세요", "좋은 아침이에요", "심심해요", "뭐 하세요",
           "누구세요", "이름이 뭐예요", "도움말", "설명해 주세요", "예시 보여 주세요", "알림 꺼 주세요",
           "오늘 몇 시예요", "지하철역 근처", "역 앞에 있는 곳", "차로 10분 거리", "토요일에 여는 곳",
           "공휴일에 여는 곳", "전화로 물어볼 곳", "평이 좋은 병원", "후기 좋은 곳", "오래된 병원",
           "규모가 큰 곳", "저렴한 병원", "비싸지 않은 곳", "카드 되나요", "주소 알려 주세요",
           "위치가 어디예요", "길 알려 주세요", "지도 보여 주세요", "아무 병원이나", "어디든 좋아요",
           "추천 부탁드려요", "알아서 골라 주세요", "zzz", "ok", "yes", "no", "abc", "123", "0000"]


def _gibberish(rng) -> str:
    """아무 뜻 없는 글자 (자판을 잘못 누르거나 시험 삼아 친 글)."""
    if rng.random() < 0.3:
        return "".join(rng.choice("abcdefghijklmnopqrstuvwxyz") for _ in range(rng.randint(2, 8)))
    return " ".join("".join(chr(0xAC00 + rng.randrange(11172)) for _ in range(rng.randint(1, 4)))
                    for _ in range(rng.randint(1, 3)))


# ---- 누구 ----

SUBJECTS = [
    Phrase(np=["아버지가", "어머니가", "아빠가", "엄마가", "할머니가", "할아버지가", "남편이", "아내가",
               "형이", "누나가", "언니가", "오빠가", "친구가", "시어머니가", "장인어른이", "저는", "제가",
               "부모님이", "어르신이", "삼촌이", "이모가", "고모가", "배우자가", "저희 엄마가", "우리 아빠가",
               "성인 아들이", "성인인 딸이", "아버님이"],
           noun=["아버지", "어머니", "아빠", "엄마", "할머니", "할아버지", "남편", "아내", "형", "누나",
                 "언니", "오빠", "친구", "시어머니", "장인어른", "부모님", "어르신", "삼촌", "이모",
                 "고모", "배우자", "성인", "노인", "저희 엄마", "우리 아빠", "어르신들"]),
    Phrase(child=True,
           np=["우리 아이가", "아이가", "아들이", "딸이", "7살 아들이", "5살 딸이", "초등학생 아들이",
               "중학생 딸이", "고등학생 아들이", "아기가", "유치원생 아이가", "10살 아이가", "손주가",
               "조카가", "우리 애가", "6살 아이가", "세 살 아기가", "초등학생 딸이", "중학생 아들이",
               "학생인 아들이", "우리 딸이", "우리 아들이", "청소년 아이가", "4살 아이가"],
           noun=["아이", "아들", "딸", "7살 아들", "5살 딸", "초등학생", "중학생", "고등학생", "아기",
                 "유치원생", "손주", "조카", "어린이", "청소년", "소아", "우리 애", "아동", "영유아",
                 "초등학생 아이", "9살 딸"]),
]

PLACES = ["병원", "곳", "병원 찾아요", "병원 알려 주세요", "병원 추천해 주세요", "곳 있나요",
          "병원 어디 있어요", "병원이 필요해요", "데 찾아요", "병원 좀 찾아 주세요", "병원 있을까요",
          "곳 추천해 주세요", "병원 어디가 좋아요", "곳을 찾고 있어요", "병원 가르쳐 주세요"]
QUESTIONS = ["어디로 가야 하나요", "어느 병원 가야 해요", "병원 추천 부탁해요", "갈 만한 병원 있을까요",
             "어디 가면 될까요", "병원 알려 주세요", "도와주세요", "어디로 가야 할지 모르겠어요",
             "병원 찾아 주세요", ""]
REGIONS = ["강남구", "서울", "부산", "대구 수성구", "인천", "광주", "대전", "수원", "성남 분당", "제주",
           "울산", "세종", "창원", "전주", "청주", "천안", "포항", "김해", "춘천", "원주", "송파구",
           "마포구", "해운대", "노원구", "강서구", "일산", "부천", "안양", "집 근처", "가까운", "근처",
           "동네", "우리 동네", "회사 근처", "근처에", "서울 강남", "경기도"]


def _all_phrases():
    return DISABILITIES + SEVERITY + NEEDS_PHRASES + FACILITY_PHRASES + SUBJECTS


def make_splits(seed: int = 7, test_share: float = 0.25):
    """표현을 학습용·평가용으로 나눈다. 같은 seed 면 늘 같게 나뉜다."""
    rng = random.Random(seed)
    for p in _all_phrases():
        p.make_split(rng, test_share)
    for name, items in (("PLACES", PLACES), ("QUESTIONS", QUESTIONS), ("REGIONS", REGIONS),
                        ("NO_NEED_PLACES", NO_NEED_PLACES), ("CHATTER", CHATTER)):
        shuffled = items[:]
        rng.shuffle(shuffled)
        n_test = max(1, round(len(shuffled) * test_share))
        _LISTS[name] = {"train": shuffled[n_test:], "test": shuffled[:n_test]}


_LISTS: dict = {}


def _word_list(rng, name, split):
    if split == "all":
        return rng.choice(_LISTS[name]["train"] + _LISTS[name]["test"])
    return rng.choice(_LISTS[name][split])


class _Sentence:
    def __init__(self):
        self.parts = []
        self.types, self.facilities, self.departments = set(), set(), set()
        self.need, self.severity, self.child = "none", "none", False

    def add(self, phrase: Phrase, text):
        if text is None:
            return False
        self.parts.append(text)
        self.types |= phrase.types
        self.facilities |= phrase.facilities
        self.departments |= phrase.departments
        if phrase.need:
            self.need = phrase.need
        if phrase.severity:
            self.severity = phrase.severity
        if phrase.child:
            self.child = True
        return True

    def labels(self):
        return {"types": sorted(self.types), "need": self.need, "severity": self.severity,
                "child": self.child, "facilities": sorted(self.facilities),
                "departments": sorted(self.departments)}


def _pick_phrase(rng, phrases, form, exclude=()):
    options = [p for p in phrases if p.has(form) and p not in exclude]
    return rng.choice(options)


# '청각장애가 심해서'처럼 정도를 뒤에 붙일 수 있는 장애 이름의 끝.
_SEVERITY_NOUN_ENDINGS = ("장애", "증", "병변", "마비", "난청", "자폐")


def _with_particle(word: str) -> str:
    """받침이 있으면 '이', 없으면 '가'를 붙인다."""
    last = word[-1]
    batchim = "가" <= last <= "힣" and (ord(last) - 0xAC00) % 28 != 0
    return word + ("이" if batchim else "가")


def _severity_after(rng, dis: Phrase, sev: Phrase, split: str):
    """'청각장애가 심해서'. 정도를 붙일 만한 장애 이름이 없으면 None."""
    for _ in range(4):
        noun = dis.pick(rng, "noun", split)
        if noun and noun.endswith(_SEVERITY_NOUN_ENDINGS):
            return f"{_with_particle(noun)} {sev.pick(rng, 'after', split)}"
    return None


def _add_disability(rng, s, dis: Phrase, sev, split: str):
    """장애 표현을 넣는다. 정도가 있으면 반쯤은 '청각장애가 심해서'처럼 붙여 쓰고 True 를 돌려준다."""
    combined = _severity_after(rng, dis, sev, split) if sev and rng.random() < 0.5 else None
    if combined:
        s.add(dis, combined)
        s.severity = sev.severity
        return True
    s.add(dis, dis.pick(rng, "conn", split))
    return False


def _noisy(rng, text: str) -> str:
    """띄어쓰기를 빼거나 문장 부호를 붙여 사람이 치는 글처럼 만든다."""
    words = text.split()
    if len(words) > 1 and rng.random() < 0.18:
        out = [words[0]]
        for w in words[1:]:
            if rng.random() < 0.4:
                out[-1] += w
            else:
                out.append(w)
        words = out
    if rng.random() < 0.04:
        words = ["".join(words)]
    text = " ".join(words)
    return text + rng.choice(["", "", "", "?", ".", "!", "요", " ㅠㅠ"])


def generate(n: int, split: str = "train", seed: int = 1) -> list[tuple[str, dict]]:
    """[n] 개의 (문장, 정답). split 이 'train'·'test' 면 그쪽 표현만, 'all' 이면 모두 쓴다."""
    if not _LISTS:
        make_splits()
    rng = random.Random(seed)
    out = []
    while len(out) < n:
        s = _Sentence()
        template = rng.choices(
            ["conn", "adn", "clause", "keywords", "first", "no_dis", "no_need", "fac_need", "nothing"],
            weights=[18, 16, 16, 18, 8, 10, 8, 6, 14])[0]
        dis = _pick_phrase(rng, DISABILITIES, "noun")
        need = _pick_phrase(rng, NEEDS_PHRASES, "noun")
        fac = _pick_phrase(rng, FACILITY_PHRASES, "noun") if rng.random() < 0.35 else None
        subj = rng.choice(SUBJECTS) if rng.random() < 0.75 else None
        sev = rng.choice(SEVERITY) if rng.random() < 0.22 else None
        second = (_pick_phrase(rng, DISABILITIES, "conn", exclude=(dis,))
                  if rng.random() < 0.12 else None)
        region = _word_list(rng, "REGIONS", split) if rng.random() < 0.3 else None
        if region and rng.random() < 0.5:
            s.parts.append(region)
            region = None

        if template == "conn":
            if subj:
                s.add(subj, subj.pick(rng, "np", split))
            joined = _add_disability(rng, s, dis, sev, split)
            if second:
                s.add(second, second.pick(rng, "conn", split))
            if sev and not joined:
                s.add(sev, sev.pick(rng, "clause", split))
            if rng.random() < 0.85:
                s.add(need, need.pick(rng, "purpose", split) or need.pick(rng, "noun", split))
                if fac:
                    s.add(fac, fac.pick(rng, "req", split))
                if region:
                    s.parts.append(region)
                s.parts.append(_word_list(rng, "PLACES", split))
            else:
                if fac:
                    s.add(fac, fac.pick(rng, "req", split))
                s.parts.append(_word_list(rng, "NO_NEED_PLACES", split))
        elif template == "adn":
            s.add(dis, dis.pick(rng, "adn", split))
            who = subj or rng.choice(SUBJECTS)
            s.add(who, who.pick(rng, "noun", split))
            if rng.random() < 0.6:
                s.add(need, need.pick(rng, "purpose", split))
            else:
                s.add(need, need.pick(rng, "noun", split))
            if fac:
                s.add(fac, fac.pick(rng, "req", split))
            if region:
                s.parts.append(region)
            s.parts.append(_word_list(rng, "PLACES", split))
        elif template == "clause":
            if subj:
                s.add(subj, subj.pick(rng, "np", split))
            joined = _add_disability(rng, s, dis, sev, split)
            if second:
                s.add(second, second.pick(rng, "conn", split))
            if sev and not joined:
                s.add(sev, sev.pick(rng, "clause", split))
            s.add(need, need.pick(rng, "clause", split) or need.pick(rng, "noun", split))
            if fac:
                if rng.random() < 0.5 and fac.has("clause"):
                    s.add(fac, fac.pick(rng, "clause", split))
                else:
                    s.add(fac, fac.pick(rng, "req", split))
                    s.parts.append(rng.choice(["곳", "병원"]))
            if region:
                s.parts.append(region)
            s.parts.append(_word_list(rng, "QUESTIONS", split))
        elif template == "keywords":
            tokens = []
            dis_word = dis.pick(rng, "noun", split)
            if sev:
                if rng.random() < 0.5:
                    dis_word = f"{sev.pick(rng, 'pre', split)} {dis_word}"
                else:
                    dis_word = f"{dis_word} {sev.pick(rng, 'post', split)}"
                s.severity = sev.severity
            tokens.append((dis, dis_word))
            if second:
                tokens.append((second, second.pick(rng, "noun", split)))
            if rng.random() < 0.85:
                tokens.append((need, need.pick(rng, "noun", split)))
            if fac:
                tokens.append((fac, fac.pick(rng, "noun", split)))
            if subj and rng.random() < 0.6:
                tokens.append((subj, subj.pick(rng, "noun", split)))
            rng.shuffle(tokens)
            for phrase, word in tokens:
                s.add(phrase, word)
            if region:
                s.parts.insert(rng.randrange(len(s.parts) + 1), region)
            if rng.random() < 0.4:
                s.parts.append(rng.choice(["병원", "추천", "찾기", "어디"]))
        elif template == "first":
            s.parts.append(rng.choice(["저는", "제가", "저", ""]))
            s.add(dis, dis.pick(rng, "clause", split))
            if sev:
                s.add(sev, sev.pick(rng, "clause", split))
            s.add(need, need.pick(rng, "clause", split) or need.pick(rng, "noun", split))
            if fac and fac.has("clause"):
                s.add(fac, fac.pick(rng, "clause", split))
            s.parts.append(_word_list(rng, "QUESTIONS", split))
        elif template == "no_dis":
            if subj:
                s.add(subj, subj.pick(rng, "np", split))
            if rng.random() < 0.5:
                s.add(need, need.pick(rng, "clause", split) or need.pick(rng, "noun", split))
                if fac:
                    s.add(fac, fac.pick(rng, "req", split))
                    s.parts.append("곳")
                s.parts.append(_word_list(rng, "QUESTIONS", split))
            else:
                if fac:
                    s.add(fac, fac.pick(rng, "req", split))
                s.add(need, need.pick(rng, "purpose", split) or need.pick(rng, "noun", split))
                s.parts.append(_word_list(rng, "PLACES", split))
        elif template == "no_need":
            s.add(dis, dis.pick(rng, "adn", split))
            who = subj or rng.choice(SUBJECTS)
            s.add(who, who.pick(rng, "noun", split))
            if fac:
                s.add(fac, fac.pick(rng, "req", split))
            s.parts.append(_word_list(rng, "NO_NEED_PLACES", split))
        elif template == "nothing":
            r = rng.random()
            if r < 0.4:
                s.parts.append(_word_list(rng, "CHATTER", split))
            elif r < 0.6:
                who = rng.choice(SUBJECTS)
                s.add(who, who.pick(rng, rng.choice(["np", "noun"]), split))
                s.parts.append(_word_list(rng, rng.choice(["PLACES", "NO_NEED_PLACES"]), split))
            elif r < 0.72:
                s.parts.append(_word_list(rng, "REGIONS", split))
                s.parts.append(_word_list(rng, "PLACES", split))
            else:
                s.parts.append(_gibberish(rng))
        else:  # fac_need
            f = fac or _pick_phrase(rng, FACILITY_PHRASES, "req")
            s.add(f, f.pick(rng, "req", split))
            if rng.random() < 0.7:
                s.add(need, need.pick(rng, "noun", split))
            else:
                s.parts.append("병원")
            if subj and rng.random() < 0.3:
                s.add(subj, subj.pick(rng, "noun", split))

        text = " ".join(p for p in s.parts if p)
        out.append((_noisy(rng, text), s.labels()))
    return out
