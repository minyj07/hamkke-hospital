"""말하듯 적은 문장을 AI 모델의 입력(특징 번호 목록)으로 바꾼다.

앱의 lib/ai/intent_features.dart 와 글자 하나까지 똑같이 계산해야 한다. 바꾸면 둘 다 바꾸고
모델을 다시 학습한다 (python tools/train_intent.py). test/ai/intent_golden.json 이 둘이 같은지 검사한다.

특징은 fastText 방식이다: 낱말, 낱말 안의 글자 1~3개 묶음, 이웃한 두 낱말.
문자열을 FNV-1a 32비트로 해시해 [BUCKETS] 칸 중 하나로 보낸다.
"""

import re

BUCKETS = 1 << 14

# 한글 음절, 영문 소문자, 숫자만 남기고 나머지는 띄어쓰기로 본다.
_DROP = re.compile(r"[^0-9a-z가-힣]+")


def normalize(text: str) -> str:
    return " ".join(_DROP.sub(" ", text.lower()).split())


def fnv1a(text: str) -> int:
    h = 0x811C9DC5
    for byte in text.encode("utf-8"):
        h ^= byte
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def feature_strings(text: str) -> list[str]:
    words = normalize(text).split()
    feats = []
    for w in words:
        feats.append("w:" + w)
        padded = "<" + w + ">"
        for n in (1, 2, 3):
            for i in range(len(padded) - n + 1):
                gram = padded[i:i + n]
                if gram in ("<", ">"):
                    continue
                feats.append(f"c{n}:{gram}")
    for a, b in zip(words, words[1:]):
        feats.append(f"b:{a}_{b}")
    return feats


def features(text: str, buckets: int = BUCKETS) -> list[int]:
    return [fnv1a(f) % buckets for f in feature_strings(text)]
