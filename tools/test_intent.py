"""메디움 AI(상황 이해 모델)의 데이터·특징·모델 파일 검사. numpy 없이 돈다.

실행: python -m unittest discover -s tools
학습은 python tools/train_intent.py (numpy 필요).
"""

import json
import re
import struct
import unittest
from pathlib import Path

from intent_data import (DEPARTMENTS, FACILITIES, NEEDS, SEVERITIES, TYPES, generate,
                         make_splits)
from intent_eval_set import EVAL, EVAL_FINAL, EVAL_NOTHING, EVAL_NOTHING_FINAL
from intent_features import BUCKETS, features, fnv1a, normalize

ROOT = Path(__file__).resolve().parent.parent


def dart_enum(path: str, enum: str) -> list[str]:
    """Dart 파일의 enum 값 이름들."""
    text = (ROOT / path).read_text(encoding="utf-8")
    body = re.search(rf"enum {enum} \{{(.*?);", text, re.S).group(1)
    return re.findall(r"^\s*(\w+)\(", body, re.M)


class LabelTest(unittest.TestCase):
    def test_정답_이름이_앱의_enum_과_같다(self):
        self.assertEqual(TYPES, [t for t in dart_enum("lib/models/disability.dart", "DisabilityType")
                                 if t != "other"])
        self.assertEqual(NEEDS[:-1], dart_enum("lib/models/disability.dart", "CareNeed"))
        self.assertEqual(NEEDS[-1], "none")
        self.assertEqual(FACILITIES, dart_enum("lib/models/hospital.dart", "Facility"))
        hospital = (ROOT / "lib/models/hospital.dart").read_text(encoding="utf-8")
        names = re.findall(r"'\d\d': '([^']+)'", hospital)
        self.assertEqual(DEPARTMENTS, names)
        self.assertEqual(SEVERITIES, ["severe", "mild", "none"])

    def test_생성한_문장과_평가_문장의_정답은_정해진_이름만_쓴다(self):
        make_splits()
        data = (generate(300, "train", seed=11) + generate(100, "all", seed=12) + EVAL + EVAL_FINAL
                + EVAL_NOTHING + EVAL_NOTHING_FINAL)
        for text, labels in data:
            self.assertTrue(text.strip(), labels)
            self.assertLessEqual(set(labels["types"]), set(TYPES), text)
            self.assertIn(labels["need"], NEEDS, text)
            self.assertIn(labels["severity"], SEVERITIES, text)
            self.assertIsInstance(labels["child"], bool, text)
            self.assertLessEqual(set(labels["facilities"]), set(FACILITIES), text)
            self.assertLessEqual(set(labels["departments"]), set(DEPARTMENTS), text)

    def test_같은_seed_면_같은_문장을_만든다(self):
        make_splits()
        self.assertEqual(generate(20, "train", seed=3), generate(20, "train", seed=3))

    def test_평가_문장은_학습_생성기에_그대로_들어_있지_않다(self):
        make_splits()
        made = {t for t, _ in generate(3000, "all", seed=4)}
        for text, _ in EVAL + EVAL_FINAL + EVAL_NOTHING + EVAL_NOTHING_FINAL:
            self.assertNotIn(text, made)


class FeatureTest(unittest.TestCase):
    def test_정규화는_소문자·한글·숫자만_남긴다(self):
        self.assertEqual(normalize("  ADHD 아이,  소아과!! "), "adhd 아이 소아과")
        self.assertEqual(normalize("ㅠㅠ"), "")

    def test_fnv1a_32비트(self):
        self.assertEqual(fnv1a(""), 0x811C9DC5)
        self.assertEqual(fnv1a("a"), 0xE40C292C)

    def test_특징은_앱이_검사하는_정답_파일과_같다(self):
        golden = json.loads((ROOT / "test/ai/intent_golden.json").read_text(encoding="utf-8"))
        for case in golden["cases"]:
            self.assertEqual(features(case["text"]), case["features"], case["text"])
        self.assertEqual(features(""), [])
        self.assertTrue(all(0 <= f < BUCKETS for f in features("휠체어 타는 아버지 재활")))


class ModelFileTest(unittest.TestCase):
    def test_앱에_넣은_모델의_머리말이_정답_이름과_크기에_맞는다(self):
        raw = (ROOT / "assets/ai/intent_model.bin").read_bytes()
        self.assertEqual(raw[:4], b"MDAI")
        version, header_len = struct.unpack_from("<HI", raw, 4)
        self.assertEqual(version, 1)
        header = json.loads(raw[10:10 + header_len].decode("utf-8"))
        heads = {h["name"]: h["labels"] for h in header["heads"]}
        self.assertEqual(heads["types"], TYPES)
        self.assertEqual(heads["need"], NEEDS)
        self.assertEqual(heads["severity"], SEVERITIES)
        self.assertEqual(heads["facilities"], FACILITIES)
        self.assertEqual(heads["departments"], DEPARTMENTS)
        buckets, dim = header["buckets"], header["dim"]
        self.assertEqual(buckets, BUCKETS)
        k = sum(len(h["labels"]) for h in header["heads"])
        body = len(raw) - 10 - header_len
        self.assertEqual(body, buckets * 4 + buckets * dim + dim * k * 4 + k * 4)


if __name__ == "__main__":
    unittest.main()
