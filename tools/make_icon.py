"""함께병원 앱 아이콘: 초록 바탕에 흰 십자, 가운데에 하트 (함께·돌봄).
assets/icon/icon.png            1024px, 둥근 네모 (iOS·예전 안드로이드 런처)
assets/icon/icon_foreground.png 1024px, 적응형 아이콘 앞면 (가운데 61% 안전 영역 안에 그림)
assets/icon/icon_monochrome.png 1024px, 안드로이드 13 테마 아이콘용 흰 실루엣
"""
import sys
from PIL import Image, ImageDraw

OUT = sys.argv[1]
_hex = sys.argv[2] if len(sys.argv) > 2 else "5B3FA0"
GREEN = tuple(int(_hex[i:i + 2], 16) for i in (0, 2, 4)) + (255,)  # 바탕색 (이름은 처음 색에서 왔다)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
S = 4  # 부드러운 가장자리를 위해 4배로 그려서 줄인다
N = 1024 * S


def cross(draw, cx, cy, span, arm, color):
    """가로·세로 둥근 막대 두 개로 십자. span 은 끝에서 끝, arm 은 막대 굵기."""
    r = arm / 2
    draw.rounded_rectangle([cx - span / 2, cy - arm / 2, cx + span / 2, cy + arm / 2], radius=r, fill=color)
    draw.rounded_rectangle([cx - arm / 2, cy - span / 2, cx + arm / 2, cy + span / 2], radius=r, fill=color)


def heart(draw, cx, cy, w, color):
    """너비 w 의 하트. 원 두 개와 아래쪽 삼각형."""
    r = w / 4
    top = cy - w * 0.18
    draw.ellipse([cx - 2 * r, top - r, cx, top + r], fill=color)
    draw.ellipse([cx, top - r, cx + 2 * r, top + r], fill=color)
    # 삼각형의 윗변은 두 원의 중심 높이보다 조금 아래, 꼭짓점은 아래쪽.
    y0 = top + r * 0.35
    x_off = 2 * r - r * 0.07
    draw.polygon([(cx - x_off, y0), (cx + x_off, y0), (cx, cy + w * 0.5)], fill=color)


def finish(img, name):
    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(f"{OUT}/{name}", optimize=True)
    return img


# 1) 적응형 앞면: 십자 폭은 전체의 54% (안전 영역 61% 안), 하트는 십자 가운데를 뚫는다.
fg = Image.new("RGBA", (N, N), CLEAR)
d = ImageDraw.Draw(fg)
cx = cy = N / 2
# flutter_launcher_icons 가 앞면을 16% 안쪽(68% 크기)으로 넣으므로 그만큼(1/0.68) 키워 그린다.
# 줄어든 뒤 십자 폭은 전체의 54% (안전 영역 61% 안), 하트는 십자 가운데를 뚫는다.
K = 1 / 0.68
cross(d, cx, cy, span=N * 0.54 * K, arm=N * 0.19 * K, color=WHITE)
mask = Image.new("L", (N, N), 0)
heart(ImageDraw.Draw(mask), cx, cy + N * 0.005 * K, w=N * 0.165 * K, color=255)
fg.paste(CLEAR, mask=mask)  # 하트 모양을 뚫어서 바탕색이 보이게 한다
finish(fg, "icon_foreground.png")

# 2) 테마 아이콘(단색): 같은 실루엣.
finish(fg.copy(), "icon_monochrome.png")

# 3) 둥근 네모 아이콘: 초록 바탕 + 같은 그림을 조금 크게.
legacy = Image.new("RGBA", (N, N), CLEAR)
d = ImageDraw.Draw(legacy)
d.rounded_rectangle([0, 0, N - 1, N - 1], radius=N * 0.22, fill=GREEN)
cross(d, cx, cy, span=N * 0.64, arm=N * 0.225, color=WHITE)
mask = Image.new("L", (N, N), 0)
heart(ImageDraw.Draw(mask), cx, cy + N * 0.005, w=N * 0.195, color=255)
legacy.paste(GREEN, mask=mask)
finish(legacy, "icon.png")

print("ok")
