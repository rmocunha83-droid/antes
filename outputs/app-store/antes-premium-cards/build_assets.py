#!/usr/bin/env python3
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parent
WORKSPACE = ROOT.parents[2]
FINAL = ROOT / "final"
LOGOS = ROOT / "logos"
REVIEW = ROOT / "review"
DATA = ROOT / "data"
POLISH = ROOT / "polish-layers"
LOGO_LAYERS = ROOT / "logo-layers"
PUSHUP = WORKSPACE / "Antes/Assets.xcassets/PushupHabit.imageset/pushup-habit.png"
REFERENCE_UI = DATA / "reference-mobile-app-interface.png"

W, H = 1290, 2796

INK = (8, 10, 17)
MUTED = (91, 98, 115)
BLUE = (0, 91, 255)
GREEN = (18, 175, 86)
SOFT = (246, 248, 252)
LINE = (214, 220, 232)
GRAPHITE = (19, 26, 41)


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont:
    candidates = {
        "black": [
            "/System/Library/Fonts/SFNSRounded.ttf",
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Supplemental/Arial Black.ttf",
        ],
        "bold": [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/HelveticaNeue.ttc",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        ],
        "regular": [
            "/System/Library/Fonts/SFNS.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
        ],
    }[weight]
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size=size)
        except Exception:
            continue
    return ImageFont.load_default()


F = {
    "hero": font(116, "black"),
    "hero2": font(104, "black"),
    "sub": font(38, "regular"),
    "brand": font(54, "black"),
    "h1": font(50, "black"),
    "h2": font(34, "bold"),
    "body": font(25, "regular"),
    "body_bold": font(25, "bold"),
    "small": font(20, "regular"),
    "small_bold": font(20, "bold"),
    "tiny": font(16, "bold"),
}


def ensure_dirs() -> None:
    for path in (FINAL, LOGOS, REVIEW, DATA, POLISH, LOGO_LAYERS):
        path.mkdir(parents=True, exist_ok=True)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return mask


def paste_round(base: Image.Image, img: Image.Image, xy: tuple[int, int], radius: int) -> None:
    base.paste(img, xy, rounded_mask(img.size, radius))


def gradient(size: tuple[int, int], colors: list[tuple[int, int, int]]) -> Image.Image:
    w, h = size
    out = Image.new("RGB", size)
    px = out.load()
    for y in range(h):
        t = y / max(1, h - 1)
        pos = t * (len(colors) - 1)
        idx = min(len(colors) - 2, int(pos))
        lt = pos - idx
        c1, c2 = colors[idx], colors[idx + 1]
        row = tuple(int(c1[i] + (c2[i] - c1[i]) * lt) for i in range(3))
        for x in range(w):
            px[x, y] = row
    return out


def draw_orb(img: Image.Image, center: tuple[int, int], radius: int, color: tuple[int, int, int], alpha: int) -> None:
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    x, y = center
    d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(*color, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(radius // 2))
    img.alpha_composite(layer)


def background(card: dict, idx: int) -> Image.Image:
    layer_path = POLISH / card.get("polishLayer", "")
    if layer_path.exists():
        layer = Image.open(layer_path).convert("RGB")
        layer = ImageOps.fit(layer, (W, H), method=Image.Resampling.LANCZOS)
        veil = Image.new("RGBA", (W, H), (248, 250, 252, 92))
        img = layer.convert("RGBA")
        img.alpha_composite(veil)
    else:
        palettes = [
            [(245, 249, 255), (232, 241, 252), (247, 251, 248)],
            [(249, 251, 255), (235, 243, 252), (238, 248, 243)],
            [(250, 252, 255), (238, 246, 255), (235, 248, 243)],
            [(250, 253, 250), (235, 247, 244), (235, 241, 252)],
            [(248, 251, 255), (239, 246, 244), (234, 241, 252)],
        ]
        img = gradient((W, H), palettes[(idx - 1) % len(palettes)]).convert("RGBA")
    draw_orb(img, (1040, 360), 360, BLUE, 28)
    draw_orb(img, (240, 2080), 420, GREEN, 24)
    draw_orb(img, (1090, 2360), 300, (255, 197, 92), 18)
    return img


def text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, font_obj, fill=INK, anchor=None) -> None:
    draw.text(xy, value, font=font_obj, fill=fill, anchor=anchor)


def wrap_text(value: str, font_obj, width: int) -> list[str]:
    words = value.split()
    lines: list[str] = []
    current = ""
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    for word in words:
        trial = f"{current} {word}".strip()
        if probe.textlength(trial, font=font_obj) <= width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_multiline(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, font_obj, fill, width: int, line_h: int) -> int:
    x, y = xy
    for line in wrap_text(value, font_obj, width):
        draw.text((x, y), line, font=font_obj, fill=fill)
        y += line_h
    return y


def shadow(base: Image.Image, box: tuple[int, int, int, int], radius: int, alpha: int, blur: int, offset: int) -> None:
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([box[0], box[1] + offset, box[2], box[3] + offset], radius, fill=(20, 30, 50, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(layer)


def phone_frame(screen: str) -> Image.Image:
    pw, ph = 725, 1570
    phone = Image.new("RGBA", (pw, ph), (0, 0, 0, 0))
    d = ImageDraw.Draw(phone)
    d.rounded_rectangle([0, 0, pw - 1, ph - 1], 92, fill=(13, 18, 29))
    d.rounded_rectangle([20, 20, pw - 21, ph - 21], 75, fill=(251, 252, 255))
    screen_x, screen_y = 32, 76
    screen_w, screen_h = pw - 64, ph - 96
    if REFERENCE_UI.exists():
        source = Image.open(REFERENCE_UI).convert("RGBA")
        crop_h = round(source.width * screen_h / screen_w)
        max_y = max(0, source.height - crop_h)
        crop_y = {
            "home": 0,
            "apps": 60,
            "composer": 190,
            "ritual": 330,
            "summary": max_y,
        }.get(screen, 0)
        crop_y = max(0, min(max_y, crop_y))
        content = source.crop((0, crop_y, source.width, crop_y + crop_h))
        viewport = content.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
    else:
        viewport = app_screen(screen, (screen_w, screen_h))
    phone.paste(viewport, (screen_x, screen_y), rounded_mask(viewport.size, 60))
    d.rounded_rectangle([270, 36, 455, 68], 16, fill=(16, 21, 31))
    return phone


def app_screen(screen: str, size: tuple[int, int]) -> Image.Image:
    img = Image.new("RGBA", size, (251, 252, 255, 255))
    d = ImageDraw.Draw(img)
    w, h = size
    y = 30
    d.text((30, y), "Antes", font=F["brand"], fill=INK)
    d.rounded_rectangle([30, y + 76, 36, y + 111], 3, fill=GREEN)
    d.text((48, y + 76), "Foco primeiro. Apps depois.", font=F["body"], fill=MUTED)
    d.rounded_rectangle([w - 160, y + 10, w - 52, y + 58], 24, fill=(246, 248, 252), outline=LINE, width=1)
    d.text((w - 106, y + 34), "7 dias", font=F["small_bold"], fill=INK, anchor="mm")
    y += 178
    if screen in ("home", "apps", "summary"):
        draw_apps_section(d, y, w)
        y += 330
    if screen in ("home", "composer", "summary"):
        draw_composer(d, y, w)
        y += 430
    if screen in ("home", "ritual", "summary"):
        draw_ritual(img, d, y, w)
        y += 420
    draw_unlock(d, min(y + 20, h - 260), w, active=screen in ("ritual", "summary"))
    return img


def card_box(draw: ImageDraw.ImageDraw, box, radius=24, fill=(255, 255, 255), outline=LINE) -> None:
    draw.rounded_rectangle(box, radius, fill=fill, outline=outline, width=2)


def draw_apps_section(d: ImageDraw.ImageDraw, y: int, w: int) -> None:
    d.text((30, y), "Apps bloqueados hoje", font=F["h2"], fill=INK)
    d.text((30, y + 44), "Eles só desbloqueiam após o hábito.", font=F["body"], fill=MUTED)
    names = [("TikTok", (7, 8, 12)), ("Instagram", (227, 60, 135)), ("YouTube", (255, 255, 255)), ("X", (10, 10, 12)), ("Discord", (88, 101, 242))]
    start_y = y + 120
    gap = 21
    icon = 92
    for i, (name, color) in enumerate(names):
        x = 30 + i * (icon + gap)
        if name == "YouTube":
            fill = (255, 255, 255)
            outline = (220, 225, 235)
        else:
            fill = color
            outline = None
        d.rounded_rectangle([x, start_y, x + icon, start_y + icon], 24, fill=fill, outline=outline, width=2 if outline else 0)
        if name == "YouTube":
            d.rounded_rectangle([x + 23, start_y + 30, x + 69, start_y + 62], 9, fill=(255, 0, 0))
            d.polygon([(x + 42, start_y + 37), (x + 42, start_y + 55), (x + 57, start_y + 46)], fill=(255, 255, 255))
        elif name == "Instagram":
            d.ellipse([x + 30, start_y + 30, x + 62, start_y + 62], outline=(255, 255, 255), width=5)
            d.ellipse([x + 65, start_y + 22, x + 74, start_y + 31], fill=(255, 255, 255))
        elif name == "Discord":
            d.rounded_rectangle([x + 24, start_y + 30, x + 68, start_y + 62], 16, fill=(255, 255, 255))
        else:
            d.text((x + icon / 2, start_y + 45), name[0], font=F["h2"], fill=(255, 255, 255), anchor="mm")
        d.ellipse([x + 64, start_y - 12, x + 101, start_y + 25], fill=(255, 255, 255), outline=LINE, width=2)
        d.text((x + 82, start_y + 6), "•", font=F["h2"], fill=GREEN, anchor="mm")
        d.text((x + icon / 2, start_y + 116), name, font=F["tiny"], fill=INK, anchor="mm")
        d.text((x + icon / 2, start_y + 140), "Bloqueado", font=F["tiny"], fill=MUTED, anchor="mm")


def draw_composer(d: ImageDraw.ImageDraw, y: int, w: int) -> None:
    d.line([30, y, w - 30, y], fill=LINE, width=2)
    y += 42
    d.text((30, y), "✦", font=F["h1"], fill=GREEN)
    d.text((82, y + 8), "Crie seu hábito com IA", font=F["h2"], fill=INK)
    d.text((30, y + 70), "A IA monta um ritual curto para você concluir antes do app.", font=F["body"], fill=MUTED)
    card_box(d, [30, y + 132, w - 30, y + 216], 22)
    d.text((56, y + 158), "10 flexões antes do TikTok", font=F["body"], fill=INK)
    chips = [("Flexões", BLUE), ("Gratidão", GREEN), ("Água", (0, 150, 210))]
    cx = 30
    for label, color in chips:
        tw = int(d.textlength(label, font=F["small_bold"])) + 52
        d.rounded_rectangle([cx, y + 244, cx + tw, y + 302], 29, fill=color if label == "Flexões" else (245, 247, 251), outline=None if label == "Flexões" else LINE)
        d.text((cx + tw / 2, y + 273), label, font=F["small_bold"], fill=(255, 255, 255) if label == "Flexões" else MUTED, anchor="mm")
        cx += tw + 14
    d.rounded_rectangle([30, y + 330, w - 30, y + 402], 20, fill=BLUE)
    d.text((w / 2, y + 366), "Gerar com OpenAI", font=F["body_bold"], fill=(255, 255, 255), anchor="mm")


def draw_ritual(img: Image.Image, d: ImageDraw.ImageDraw, y: int, w: int) -> None:
    d.line([30, y, w - 30, y], fill=LINE, width=2)
    y += 34
    d.text((30, y), "Flexões antes do app", font=F["h2"], fill=INK)
    d.rounded_rectangle([370, y + 3, 448, y + 38], 18, fill=(232, 248, 240))
    d.text((409, y + 21), "Novo", font=F["tiny"], fill=GREEN, anchor="mm")
    d.text((30, y + 54), "Força • 10 flexões completas • ~2 min", font=F["body"], fill=MUTED)
    if PUSHUP.exists():
        photo = Image.open(PUSHUP).convert("RGB")
        photo = ImageOps.fit(photo, (210, 166), method=Image.Resampling.LANCZOS)
        paste_round(img, photo.convert("RGBA"), (30, y + 118), 18)
    else:
        d.rounded_rectangle([30, y + 118, 240, y + 284], 18, fill=(230, 236, 245))
    steps = [("1. Execução", "10 flexões completas", "0/10"), ("2. Descanso", "30 segundos", "00:30"), ("3. Conclusão", "Marque como concluído", "")]
    sy = y + 112
    for title, detail, stat in steps:
        d.ellipse([270, sy, 330, sy + 60], fill=(229, 247, 237))
        d.text((300, sy + 30), "✓" if title.startswith("3") else "•", font=F["body_bold"], fill=GREEN, anchor="mm")
        d.text((350, sy + 4), title, font=F["small_bold"], fill=INK)
        d.text((350, sy + 34), detail, font=F["small"], fill=MUTED)
        if stat:
            d.ellipse([w - 102, sy + 2, w - 42, sy + 62], outline=GREEN, width=4)
            d.text((w - 72, sy + 32), stat, font=F["tiny"], fill=MUTED, anchor="mm")
        sy += 82


def draw_unlock(d: ImageDraw.ImageDraw, y: int, w: int, active: bool = False) -> None:
    fill = (236, 248, 242) if active else (238, 244, 255)
    tint = GREEN if active else BLUE
    d.rounded_rectangle([30, y, w - 30, y + 88], 20, fill=fill, outline=tuple(int(c * 0.8) for c in fill), width=2)
    d.text((62, y + 44), "✓" if active else "↗", font=F["body_bold"], fill=tint, anchor="mm")
    d.text((96, y + 28), "Ao concluir, libere por 15 minutos.", font=F["body"], fill=MUTED)
    d.rounded_rectangle([30, y + 122, w - 30, y + 206], 20, fill=tint)
    d.text((w / 2, y + 164), "Ativar ritual e bloquear apps" if not active else "Ritual ativo", font=F["body_bold"], fill=(255, 255, 255), anchor="mm")


def make_card(card: dict, idx: int) -> Path:
    img = background(card, idx)
    d = ImageDraw.Draw(img)
    d.text((86, 124), "ANTES", font=F["tiny"], fill=(69, 78, 96))
    d.text((86, 250), card["headline"], font=F["hero"], fill=INK)
    d.text((86, 374), card["headline2"], font=F["hero2"], fill=INK)
    draw_multiline(d, (88, 520), card["subhead"], F["sub"], MUTED, 850, 54)
    phone = phone_frame(card["screen"])
    phone_x = (W - phone.width) // 2
    phone_y = 790
    shadow(img, (phone_x, phone_y, phone_x + phone.width, phone_y + phone.height), 98, 74, 44, 28)
    img.alpha_composite(phone, (phone_x, phone_y))
    d.rounded_rectangle([390, 2400, 900, 2482], 41, fill=(255, 255, 255, 220), outline=(225, 231, 240), width=2)
    d.text((645, 2441), "Foco primeiro. Apps depois.", font=F["body_bold"], fill=INK, anchor="mm")
    out = FINAL / f"{idx:02d}-{card['id']}.png"
    img.convert("RGB").save(out, quality=96)
    return out


def draw_mark(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill=BLUE, accent=GREEN) -> None:
    x1, y1, x2, y2 = box
    w = x2 - x1
    h = y2 - y1
    draw.rounded_rectangle([x1 + w * 0.18, y1 + h * 0.16, x1 + w * 0.48, y1 + h * 0.82], int(w * 0.08), fill=fill)
    draw.rounded_rectangle([x1 + w * 0.52, y1 + h * 0.16, x1 + w * 0.82, y1 + h * 0.82], int(w * 0.08), fill=fill)
    draw.rounded_rectangle([x1 + w * 0.36, y1 + h * 0.48, x1 + w * 0.64, y1 + h * 0.68], int(w * 0.06), fill=accent)


def make_app_icon() -> Path:
    size = 1024
    icon = gradient((size, size), [(247, 251, 255), (235, 246, 242), (229, 238, 255)]).convert("RGBA")
    draw_orb(icon, (810, 210), 270, BLUE, 42)
    draw_orb(icon, (250, 780), 320, GREEN, 35)
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([158, 158, 866, 866], 188, fill=(255, 255, 255, 176), outline=(255, 255, 255, 210), width=4)
    layer = layer.filter(ImageFilter.GaussianBlur(0.25))
    icon.alpha_composite(layer)
    d = ImageDraw.Draw(icon)
    shadow(icon, (260, 230, 764, 790), 84, 55, 38, 24)
    draw_mark(d, (286, 252, 738, 792), fill=BLUE, accent=GREEN)
    out = LOGOS / "antes-app-icon-1024.png"
    icon.convert("RGB").save(out, quality=96)
    return out


def make_logo_pngs() -> list[Path]:
    outs = []
    for name, size, stacked in [
        ("antes-logo-horizontal.png", (1600, 520), False),
        ("antes-logo-stacked.png", (1200, 1200), True),
        ("antes-logo-dark.png", (1600, 520), False),
    ]:
        dark = name.endswith("dark.png")
        img = Image.new("RGBA", size, GRAPHITE if dark else (255, 255, 255))
        d = ImageDraw.Draw(img)
        mark_box = (90, 110, 390, 410) if not stacked else (390, 145, 810, 565)
        draw_mark(d, mark_box, fill=(255, 255, 255) if dark else BLUE, accent=GREEN)
        if stacked:
            d.text((size[0] / 2, 715), "Antes", font=font(162, "black"), fill=(255, 255, 255) if dark else INK, anchor="mm")
            d.text((size[0] / 2, 828), "Foco primeiro. Apps depois.", font=font(42, "regular"), fill=(198, 207, 222) if dark else MUTED, anchor="mm")
        else:
            d.text((470, 206), "Antes", font=font(154, "black"), fill=(255, 255, 255) if dark else INK)
            d.text((480, 350), "Foco primeiro. Apps depois.", font=font(42, "regular"), fill=(198, 207, 222) if dark else MUTED)
        out = LOGOS / name
        img.convert("RGB").save(out, quality=96)
        outs.append(out)
    svg = LOGOS / "antes-logo-horizontal.svg"
    svg.write_text(
        """<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="520" viewBox="0 0 1600 520">
<rect width="1600" height="520" fill="#fff"/>
<g>
<rect x="144" y="158" width="90" height="204" rx="26" fill="#005BFF"/>
<rect x="246" y="158" width="90" height="204" rx="26" fill="#005BFF"/>
<rect x="198" y="254" width="84" height="62" rx="22" fill="#12AF56"/>
</g>
<text x="470" y="322" font-family="SF Pro Display, Helvetica Neue, Arial, sans-serif" font-size="154" font-weight="900" fill="#080A11">Antes</text>
<text x="480" y="397" font-family="SF Pro Text, Helvetica Neue, Arial, sans-serif" font-size="42" fill="#5B6273">Foco primeiro. Apps depois.</text>
</svg>
""",
        encoding="utf-8",
    )
    outs.append(svg)
    return outs


def make_logo_routes() -> list[Path]:
    spec = json.loads((DATA / "logo-spec.json").read_text(encoding="utf-8"))
    outs = []
    for idx, route in enumerate(spec["routes"], start=1):
        src = LOGO_LAYERS / f"{route['id']}.png"
        tile = Image.new("RGBA", (1080, 1080), (255, 255, 255, 255))
        d = ImageDraw.Draw(tile)
        if src.exists():
            layer = Image.open(src).convert("RGB")
            layer = ImageOps.fit(layer, (760, 760), method=Image.Resampling.LANCZOS)
            paste_round(tile, layer.convert("RGBA"), (160, 80), 112)
        else:
            d.rounded_rectangle([220, 110, 860, 750], 150, fill=(244, 248, 255), outline=LINE, width=3)
            draw_mark(d, (350, 230, 730, 650), fill=BLUE, accent=GREEN)
        d.text((540, 862), route["label"], font=font(54, "black"), fill=INK, anchor="mm")
        d.text((540, 928), route["family"].upper(), font=font(24, "bold"), fill=MUTED, anchor="mm")
        out = LOGOS / f"{idx:02d}-{route['id']}-logo-route.png"
        tile.convert("RGB").save(out, quality=96)
        outs.append(out)
    return outs


def write_manifests(cards: list[Path], logo_routes: list[Path], app_icon: Path, logo_pngs: list[Path]) -> None:
    card_manifest = [
        {"id": p.stem, "title": p.stem.split("-", 1)[1].replace("-", " ").title(), "src": f"../final/{p.name}", "href": f"../final/{p.name}", "index": i}
        for i, p in enumerate(cards, start=1)
    ]
    (DATA / "review-manifest.json").write_text(json.dumps(card_manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    logo_manifest = []
    for i, p in enumerate([app_icon, *logo_pngs, *logo_routes], start=1):
        if p.suffix.lower() != ".png":
            continue
        logo_manifest.append({"id": p.stem, "title": p.stem.replace("-", " ").title(), "src": f"../logos/{p.name}", "href": f"../logos/{p.name}", "index": i})
    (DATA / "logo-review-manifest.json").write_text(json.dumps(logo_manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    all_manifest = card_manifest + logo_manifest
    (DATA / "all-assets-manifest.json").write_text(json.dumps(all_manifest, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> None:
    ensure_dirs()
    cards_data = json.loads((DATA / "cards.json").read_text(encoding="utf-8"))["cards"]
    cards = [make_card(card, idx) for idx, card in enumerate(cards_data, start=1)]
    app_icon = make_app_icon()
    logo_pngs = make_logo_pngs()
    logo_routes = make_logo_routes()
    write_manifests(cards, logo_routes, app_icon, logo_pngs)
    print(json.dumps({
        "cards": [str(p) for p in cards],
        "app_icon": str(app_icon),
        "logos": [str(p) for p in logo_pngs],
        "logo_routes": [str(p) for p in logo_routes],
    }, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
