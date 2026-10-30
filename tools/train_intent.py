"""메디움 AI: 말하듯 적은 문장에서 병원 찾기 조건을 알아내는 작은 신경망을 학습한다.

    python tools/train_intent.py          # numpy 필요 (pip install numpy)

모델은 fastText 방식이다 (Joulin 외, 2016). 문장의 특징(낱말·글자 조각, intent_features.py)마다
임베딩 벡터를 두고 평균을 낸 뒤, 여섯 갈래 출력으로 조건을 맞힌다:
장애 유형(여러 개), 진료 목적(하나), 장애 정도(하나), 어린이인지, 편의시설(여러 개), 진료과(여러 개).
여러 일을 한 임베딩으로 함께 배워서(멀티태스크) 작은 모델로도 잘 맞힌다.

만드는 파일:
- assets/ai/intent_model.bin: 앱에 넣는 모델. 임베딩은 8비트로 줄여 1MB 안팎이다.
- test/ai/intent_golden.json: 앱(Dart)과 이 스크립트의 계산이 같은지 검사할 정답.
- tools/intent_metrics.json: 평가 결과 (키워드 방식과 비교).

학습 데이터는 intent_data.py 가 만든다. 두 번 학습한다:
1) 검증 모델: 표현의 4분의 1을 학습에서 빼고 배워서, 못 본 표현을 얼마나 알아듣는지 잰다.
2) 앱 모델: 모든 표현으로 배운다. 앱에 넣고, 직접 쓴 문장(intent_eval_set.py)으로 잰다.
   조정용 문장(EVAL)은 생성기를 보강하는 데 썼고, 최종 평가 문장(EVAL_FINAL)은 그 전에 써 두었다.
   조건 없는 글(EVAL_NOTHING)은 '조건 없는 글' 틀을 넣기 전에 써 두었고 그 틀을 보강하는 데 썼다.
   조건 없는 글의 최종 평가 문장(EVAL_NOTHING_FINAL)은 두 번째 보강 전에 써 두었다.

특징이 하나도 없는 글(ㅋㅋ, 이모티콘만 쓴 글)은 모델을 돌리지 않고 아무 조건도 없다고 본다 (앱도 같다).

    python tools/train_intent.py [에폭 수] [임베딩 크기]
"""

import json
import struct
import sys
import time
from pathlib import Path

import numpy as np

from intent_data import DEPARTMENTS, FACILITIES, NEEDS, SEVERITIES, TYPES, generate, make_splits
from intent_eval_set import EVAL, EVAL_FINAL, EVAL_NOTHING, EVAL_NOTHING_FINAL
from intent_features import BUCKETS, features

ROOT = Path(__file__).resolve().parent.parent
MODEL_OUT = ROOT / "assets" / "ai" / "intent_model.bin"
GOLDEN_OUT = ROOT / "test" / "ai" / "intent_golden.json"
METRICS_OUT = ROOT / "tools" / "intent_metrics.json"

MAGIC = b"MDAI"
VERSION = 1
DIM = 48
SEED = 20261030

HEADS = [
    ("types", "sigmoid", TYPES),
    ("need", "softmax", NEEDS),
    ("severity", "softmax", SEVERITIES),
    ("child", "sigmoid", ["child"]),
    ("facilities", "sigmoid", FACILITIES),
    ("departments", "sigmoid", DEPARTMENTS),
]
SLICES = {}
_start = 0
for _name, _kind, _labels in HEADS:
    SLICES[_name] = slice(_start, _start + len(_labels))
    _start += len(_labels)
K = _start


# ---- 정답 ----

def target(labels: dict) -> np.ndarray:
    y = np.zeros(K, dtype=np.float32)
    for t in labels["types"]:
        y[SLICES["types"].start + TYPES.index(t)] = 1
    y[SLICES["need"].start + NEEDS.index(labels["need"])] = 1
    y[SLICES["severity"].start + SEVERITIES.index(labels["severity"])] = 1
    y[SLICES["child"].start] = 1 if labels["child"] else 0
    for f in labels["facilities"]:
        y[SLICES["facilities"].start + FACILITIES.index(f)] = 1
    for d in labels["departments"]:
        y[SLICES["departments"].start + DEPARTMENTS.index(d)] = 1
    return y


def activate(logits: np.ndarray) -> np.ndarray:
    """출력 갈래마다 sigmoid 나 softmax 를 씌운다. logits: (N, K)."""
    out = np.empty_like(logits)
    for name, kind, _ in HEADS:
        z = logits[:, SLICES[name]]
        if kind == "sigmoid":
            # 아주 큰 음수면 exp 가 무한대가 되어 0 이 된다 (앱의 Dart 계산도 같다).
            with np.errstate(over="ignore"):
                out[:, SLICES[name]] = 1 / (1 + np.exp(-z))
        else:
            e = np.exp(z - z.max(axis=1, keepdims=True))
            out[:, SLICES[name]] = e / e.sum(axis=1, keepdims=True)
    return out


# 아무 조건도 없는 답. 특징이 없는 글은 모델을 돌리지 않고 이것으로 본다.
NOTHING = {"types": [], "need": "none", "severity": "none", "child": False, "facilities": [],
           "departments": []}


def decode(p: np.ndarray) -> dict:
    """확률 한 줄을 조건으로 바꾼다. 앱의 IntentModel.predict 와 같은 규칙이다."""
    def multi(name, labels):
        return sorted(lbl for lbl, v in zip(labels, p[SLICES[name]]) if v >= 0.5)

    def one(name, labels):
        return labels[int(np.argmax(p[SLICES[name]]))]

    return {"types": multi("types", TYPES), "need": one("need", NEEDS),
            "severity": one("severity", SEVERITIES), "child": bool(p[SLICES["child"].start] >= 0.5),
            "facilities": multi("facilities", FACILITIES),
            "departments": multi("departments", DEPARTMENTS)}


# ---- 모델 ----

class Model:
    def __init__(self, rng: np.random.Generator, dim: int = DIM):
        self.dim = dim
        self.E = rng.uniform(-1 / dim, 1 / dim, (BUCKETS, dim)).astype(np.float32)
        self.W = np.zeros((dim, K), dtype=np.float32)
        self.b = np.zeros(K, dtype=np.float32)

    @staticmethod
    def _bag(feats: list[list[int]]):
        idx = np.concatenate([np.asarray(f, dtype=np.int64) for f in feats])
        seg = np.concatenate([np.full(len(f), i) for i, f in enumerate(feats)])
        w = np.concatenate([np.full(len(f), 1 / len(f), dtype=np.float32) for f in feats])
        return idx, seg, w

    def hidden(self, feats, E=None):
        E = self.E if E is None else E
        h = np.zeros((len(feats), self.dim), dtype=E.dtype)
        idx, seg, w = self._bag(feats)
        np.add.at(h, seg, E[idx] * w[:, None])
        return h

    def predict(self, feats, E=None) -> np.ndarray:
        h = self.hidden(feats, E)
        return activate(h @ self.W + self.b)


def train(model: Model, data, epochs: int, rng: np.random.Generator, lr=0.01, batch=128,
          dropout=0.1):
    data = [(t, l) for t, l in data if features(t)]
    feats = [features(t) for t, _ in data]
    ys = np.stack([target(l) for _, l in data])
    params = [model.E, model.W, model.b]
    m = [np.zeros_like(p) for p in params]
    v = [np.zeros_like(p) for p in params]
    step = 0
    for epoch in range(epochs):
        order = rng.permutation(len(data))
        total = 0.0
        for s in range(0, len(order), batch):
            ids = order[s:s + batch]
            # 특징 일부를 빼고 배워서 처음 보는 표현에도 덜 흔들리게 한다.
            fb = []
            for i in ids:
                f = feats[i]
                keep = [x for x in f if rng.random() >= dropout]
                fb.append(keep or f)
            y = ys[ids]
            idx, seg, w = Model._bag(fb)
            h = np.zeros((len(ids), model.dim), dtype=np.float32)
            np.add.at(h, seg, model.E[idx] * w[:, None])
            p = activate(h @ model.W + model.b)
            g = (p - y) / len(ids)  # sigmoid·softmax 와 교차 엔트로피의 기울기
            total += float(-np.sum(y * np.log(np.clip(p, 1e-7, 1))))
            dW = h.T @ g
            db = g.sum(axis=0)
            dh = g @ model.W.T
            dE = np.zeros_like(model.E)
            np.add.at(dE, idx, dh[seg] * w[:, None])
            step += 1
            for param, grad, mi, vi in zip(params, (dE, dW, db), m, v):
                mi *= 0.9
                mi += 0.1 * grad
                vi *= 0.999
                vi += 0.001 * grad * grad
                param -= lr * (mi / (1 - 0.9 ** step)) / (np.sqrt(vi / (1 - 0.999 ** step)) + 1e-8)
        print(f"  {epoch + 1:2d}번째: 손실 {total / len(data):.3f}")


def quantize(E: np.ndarray):
    """임베딩 줄마다 8비트로 줄인다. 앱에서 q * scale 로 되돌린다."""
    scale = np.abs(E).max(axis=1) / 127
    safe = np.where(scale == 0, 1, scale)
    q = np.clip(np.round(E / safe[:, None]), -127, 127).astype(np.int8)
    return q, scale.astype(np.float32)


# ---- 평가 ----

def keyword_baseline(text: str) -> dict:
    """비교용 키워드 방식: 장애·진료·시설 이름과 흔한 낱말이 글에 있는지만 본다."""
    t = text.replace(" ", "")
    types = set()
    for key, value in [("지체", "physical"), ("휠체어", "physical"), ("뇌병변", "brainLesion"),
                       ("뇌성마비", "brainLesion"), ("시각", "visual"), ("청각", "hearing"),
                       ("언어장애", "speech"), ("지적", "intellectual"), ("자폐", "autism"),
                       ("정신장애", "mental"), ("신장", "kidney"), ("투석", "kidney"),
                       ("심장", "heart"), ("호흡기", "respiratory"), ("간장애", "liver"),
                       ("안면", "facial"), ("장루", "ostomy"), ("요루", "ostomy"),
                       ("뇌전증", "epilepsy")]:
        if key in t:
            types.add(value)
    if "발달장애" in t:
        types |= {"intellectual", "autism"}
    need = "none"
    for value, keys in [("dental", ["치과", "충치", "스케일링", "치아", "잇몸"]),
                        ("rehab", ["재활", "물리치료", "언어치료", "작업치료"]),
                        ("checkup", ["검진"]),
                        ("pregnancy", ["임신", "출산", "산부인과", "산모", "분만"]),
                        ("mentalHealth", ["정신과", "상담", "우울", "공황", "불안", "정신건강"]),
                        ("chronic", ["당뇨", "혈압", "만성", "주치의", "꾸준히", "정기"]),
                        ("general", ["감기", "내과", "소아과", "몸살", "독감", "예방접종"])]:
        if any(k in t for k in keys):
            need = value
            break
    departments = set(d for d in DEPARTMENTS if d in t)
    for key, depts in [("피부", {"피부과"}), ("눈", {"안과"}), ("귀", {"이비인후과"}),
                       ("허리", {"정형외과", "신경외과", "마취통증의학과"}), ("무릎", {"정형외과"}),
                       ("소변", {"비뇨의학과"}), ("비뇨", {"비뇨의학과"}), ("두통", {"신경과"}),
                       ("어지럼", {"신경과"}), ("치매", {"신경과"}), ("파킨슨", {"신경과"}),
                       ("욕창", {"성형외과", "피부과", "외과"}), ("흉터", {"성형외과"})]:
        if key in t:
            departments |= depts
    if need == "none" and departments:
        need = "other"
    severity = "none"
    if any(k in t for k in ["중증", "심한", "1급", "2급", "3급"]):
        severity = "severe"
    elif any(k in t for k in ["경증", "4급", "5급", "6급", "심하지"]):
        severity = "mild"
    child = any(k in t for k in ["아이", "아들", "딸", "어린이", "소아", "청소년", "학생", "아기",
                                 "애가", "손주", "조카"])
    facilities = set()
    for key, value in [("휠체어", "wheelchair"), ("경사로", "wheelchair"), ("엘리베이터", "wheelchair"),
                       ("주차", "parking"), ("화장실", "toilet"), ("리프트", "lift"),
                       ("검사대", "lift"), ("수어", "signLanguage"), ("점자", "braille"),
                       ("음성안내", "braille"), ("수면", "sedation"), ("진정", "sedation"),
                       ("마취", "sedation"), ("조용", "quietRoom"), ("투석", "dialysis"),
                       ("인공신장", "dialysis")]:
        if key in t:
            facilities.add(value)
    return {"types": sorted(types), "need": need, "severity": severity, "child": child,
            "facilities": sorted(facilities), "departments": sorted(departments)}


def _f1(golds, preds):
    tp = sum(len(set(g) & set(p)) for g, p in zip(golds, preds))
    fp = sum(len(set(p) - set(g)) for g, p in zip(golds, preds))
    fn = sum(len(set(g) - set(p)) for g, p in zip(golds, preds))
    return 2 * tp / (2 * tp + fp + fn) if tp else 0.0


def score(golds: list[dict], preds: list[dict]) -> dict:
    n = len(golds)

    def acc(key):
        return sum(g[key] == p[key] for g, p in zip(golds, preds)) / n

    other = [(g, p) for g, p in zip(golds, preds) if g["need"] == "other"]
    return {
        "문장 수": n,
        "장애 유형 정확도": acc("types"),
        "장애 유형 F1": _f1([g["types"] for g in golds], [p["types"] for p in preds]),
        "진료 목적 정확도": acc("need"),
        "장애 정도 정확도": acc("severity"),
        "어린이 정확도": acc("child"),
        "편의시설 정확도": acc("facilities"),
        "편의시설 F1": _f1([g["facilities"] for g in golds], [p["facilities"] for p in preds]),
        "진료과 맞힘(기타 진료)": (sum(bool(set(g["departments"]) & set(p["departments"]))
                                  for g, p in other) / len(other)) if other else None,
        "핵심 조건 모두 맞힘": sum(g["types"] == p["types"] and g["need"] == p["need"]
                               and g["child"] == p["child"] for g, p in zip(golds, preds)) / n,
    }


def print_scores(title: str, s: dict):
    print(f"\n[{title}]")
    for key, value in s.items():
        print(f"  {key}: {value if isinstance(value, int) or value is None else f'{value:.1%}'}")


# ---- 내보내기 ----

def export(model: Model, q: np.ndarray, scale: np.ndarray, metrics: dict):
    header = {
        "format": "메디움 상황 이해 모델 (fastText 방식, 임베딩 8비트)",
        "buckets": BUCKETS, "dim": model.dim,
        "heads": [{"name": n, "kind": k, "labels": l} for n, k, l in HEADS],
        "trained": time.strftime("%Y-%m-%d"),
        "final_eval_all_core": metrics["앱 모델"]["최종 평가 문장"]["AI"]["핵심 조건 모두 맞힘"],
    }
    raw = json.dumps(header, ensure_ascii=False).encode("utf-8")
    MODEL_OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(MODEL_OUT, "wb") as f:
        f.write(MAGIC)
        f.write(struct.pack("<HI", VERSION, len(raw)))
        f.write(raw)
        f.write(scale.astype("<f4").tobytes())
        f.write(q.tobytes())
        f.write(model.W.astype("<f4").tobytes())
        f.write(model.b.astype("<f4").tobytes())
    print(f"\n모델: {MODEL_OUT.relative_to(ROOT)} ({MODEL_OUT.stat().st_size / 1e6:.2f}MB)")


def golden(model: Model, q: np.ndarray, scale: np.ndarray):
    """앱의 계산과 비교할 정답. 앱처럼 8비트 임베딩을 되돌려 double 로 계산한다."""
    E64 = q.astype(np.float64) * scale.astype(np.float64)[:, None]
    texts = [t for t, _ in EVAL[:24]] + ["", "  !!  ", "ADHD 아이 소아과", "휠체어타는엄마재활",
                                         "안녕하세요", "ㅋㅋ", "청각장애가 심해서 수어 되는 곳"]
    cases = []
    for t in texts:
        f = features(t)
        if f:
            h = E64[f].mean(axis=0)
        else:
            h = np.zeros(model.dim)
        logits = h @ model.W.astype(np.float64) + model.b.astype(np.float64)
        p = activate(logits[None, :])[0]
        cases.append({"text": t, "features": f, "probabilities": [round(float(x), 9) for x in p],
                      "decoded": decode(p) if f else dict(NOTHING)})
    GOLDEN_OUT.parent.mkdir(parents=True, exist_ok=True)
    GOLDEN_OUT.write_text(json.dumps({"cases": cases}, ensure_ascii=False, indent=1) + "\n",
                          encoding="utf-8")
    print(f"정답 파일: {GOLDEN_OUT.relative_to(ROOT)} ({len(cases)}문장)")


def evaluate(model: Model, sets, show_wrong=()) -> dict:
    """[sets] 마다 8비트 모델과 키워드 방식을 비교한다."""
    q, scale = quantize(model.E)
    Eq = (q.astype(np.float32) * scale[:, None]).astype(np.float32)
    out = {}
    for title, data in sets:
        golds = [l for _, l in data]
        feats = [features(t) or [0] for t, _ in data]
        ai = [decode(p) if features(t) else dict(NOTHING)
              for (t, _), p in zip(data, model.predict(feats, Eq))]
        kw = [keyword_baseline(t) for t, _ in data]
        out[title] = {"AI": score(golds, ai), "키워드 방식": score(golds, kw)}
        print_scores(f"{title} · AI", out[title]["AI"])
        print_scores(f"{title} · 키워드 방식", out[title]["키워드 방식"])
        if title in show_wrong:
            wrong = [(t, g, p) for (t, g), p in zip(data, ai)
                     if (g["types"], g["need"], g["child"]) != (p["types"], p["need"], p["child"])]
            print(f"\n  [{title}] 핵심 조건을 틀린 문장 {len(wrong)}개:")
            for t, g, p in wrong:
                print(f"   - {t}\n     정답 {g['types']} {g['need']} 어린이={g['child']}"
                      f" / AI {p['types']} {p['need']} 어린이={p['child']}")
    return out


def main():
    epochs = int(sys.argv[1]) if len(sys.argv) > 1 else 14
    dim = int(sys.argv[2]) if len(sys.argv) > 2 else DIM
    rng = np.random.default_rng(SEED)
    make_splits()
    metrics = {"설정": {"에폭": epochs, "임베딩 크기": dim, "칸 수": BUCKETS}}

    print("=== 1) 검증 모델: 평가용 표현을 빼고 학습 ===")
    train_set = generate(30000, "train", seed=1)
    test_set = generate(4000, "test", seed=2)
    print(f"학습 문장 {len(train_set)}개, 못 본 표현 평가 {len(test_set)}개")
    check = Model(rng, dim)
    started = time.time()
    train(check, train_set, epochs, rng)
    print(f"학습 시간 {time.time() - started:.0f}초")
    metrics["검증 모델"] = evaluate(check, [("못 본 표현", test_set), ("조정용 문장", EVAL),
                                          ("최종 평가 문장", EVAL_FINAL),
                                          ("조건 없는 글", EVAL_NOTHING),
                                          ("조건 없는 글 최종", EVAL_NOTHING_FINAL)])

    print("\n=== 2) 앱 모델: 모든 표현으로 학습 ===")
    final = Model(rng, dim)
    started = time.time()
    train(final, generate(30000, "all", seed=3), epochs, rng)
    print(f"학습 시간 {time.time() - started:.0f}초")
    metrics["앱 모델"] = evaluate(final, [("조정용 문장", EVAL), ("최종 평가 문장", EVAL_FINAL),
                                        ("조건 없는 글", EVAL_NOTHING),
                                        ("조건 없는 글 최종", EVAL_NOTHING_FINAL)],
                                show_wrong=("조정용 문장", "최종 평가 문장", "조건 없는 글",
                                            "조건 없는 글 최종"))

    METRICS_OUT.write_text(json.dumps(metrics, ensure_ascii=False, indent=1) + "\n",
                           encoding="utf-8")
    q, scale = quantize(final.E)
    export(final, q, scale, metrics)
    golden(final, q, scale)


if __name__ == "__main__":
    main()
