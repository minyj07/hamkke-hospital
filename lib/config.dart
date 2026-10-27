// 빌드할 때 --dart-define=이름=값 으로 바꿀 수 있는 설정.

/// 최신 병원 데이터를 올려 둔 주소. .github/workflows/update-data.yml 이 저장소의 data 브랜치에
/// 올린다. 이 계정의 GitHub Pages 는 HTTP 로만 열려서 HTTPS 인 raw.githubusercontent.com 을 쓴다.
/// 빈 값을 주면 앱에 든 데이터만 쓴다.
const dataBaseUrl = String.fromEnvironment(
  'DATA_BASE_URL',
  defaultValue: 'https://raw.githubusercontent.com/minyj07/hamkke-hospital/data/v1/',
);

/// 네이버 클라우드 플랫폼 Maps 의 Client ID (Application 등록 → Dynamic Map). 저장소에는 넣지 않고
/// 빌드할 때 넣는다. 없으면 추천 결과의 지도 보기를 숨긴다.
const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

/// '정보가 틀렸어요' 신고와 문의를 받는 메일 주소.
const contactEmail = String.fromEnvironment(
  'CONTACT_EMAIL',
  defaultValue: 'minyj07@gmail.com',
);
