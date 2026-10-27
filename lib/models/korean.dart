// 앞 낱말의 받침에 맞춰 조사를 붙인다. 사용자가 입력한 이름·장애로 문장을 만들 때 쓴다.

/// [word] 의 마지막 글자에 받침이 있는지. 마지막 글자가 한글이 아니면 null.
bool? hasFinalConsonant(String word) {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return null;
  final code = trimmed.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return null;
  return (code - 0xAC00) % 28 != 0;
}

String _attach(String word, String withFinal, String withoutFinal, String unknown) =>
    word + switch (hasFinalConsonant(word)) {
      true => withFinal,
      false => withoutFinal,
      null => unknown,
    };

/// 이/가 (예: 청각장애가, 척수손상이).
String subjectParticle(String word) => _attach(word, '이', '가', '이(가)');

/// 이에요/예요 (예: 김함께예요, 이지현이에요).
String copula(String word) => _attach(word, '이에요', '예요', '(이)에요');

/// 이란/란 (예: 장애인 건강주치의란, 국립재활원이란).
String topicQuestion(String word) => _attach(word, '이란', '란', '(이)란');
