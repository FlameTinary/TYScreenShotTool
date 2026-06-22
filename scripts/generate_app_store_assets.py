from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ICON_PATH = ROOT / "TYScreenShotTool" / "Assets.xcassets" / "AppIcon.appiconset" / "shot_image 3.png"
SCREENSHOT_DIR = ROOT / "screenshot"
OUTPUT_DIR = ROOT / "docs" / "AppStore"

CANVAS_SIZE = (2880, 1800)
FONT_SANS = "/System/Library/Fonts/Hiragino Sans GB.ttc"
FONT_ROUNDED = "/System/Library/Fonts/SFNSRounded.ttf"
FONT_MONO = "/System/Library/Fonts/SFNSMono.ttf"


@dataclass(frozen=True)
class PreviewSpec:
    filename: str
    eyebrow: str
    title: str
    subtitle: str
    bullets: list[str]
    accent: tuple[int, int, int]
    accent_two: tuple[int, int, int]
    screenshot_name: str
    screenshot_label: str
    dark_screenshot: bool = False
    focus_crop: tuple[float, float, float, float] | None = None
    focus_position: str = "bottom_right"


SPECS = [
    PreviewSpec(
        filename="tshot-preview-01-capture-edit.png",
        eyebrow="TShot for Mac",
        title="截图后立刻进入编辑",
        subtitle="框选、微调、复制、保存，所有常用动作都在同一条工作流里完成。",
        bullets=["顶部样式栏直接调整圆角与阴影", "底部工具栏集中提供标注与导出动作", "真实截图结果所见即所得"],
        accent=(33, 129, 255),
        accent_two=(109, 72, 255),
        screenshot_name="截图操作面板.png",
        screenshot_label="普通截图编辑",
        dark_screenshot=False,
        focus_crop=(0.08, 0.82, 0.96, 0.98),
        focus_position="bottom_right",
    ),
    PreviewSpec(
        filename="tshot-preview-02-annotation.png",
        eyebrow="Scroll Capture",
        title="滚动内容自动拼成长图",
        subtitle="进入长截图模式后继续滚动页面，TShot 会在同一选区里持续追加内容。",
        bullets=["长截图过程中保持边界清晰可见", "底部只保留取消、保存、复制三个核心动作", "适合网页、文档和技术资料的连续截取"],
        accent=(255, 149, 0),
        accent_two=(255, 59, 48),
        screenshot_name="长截图.png",
        screenshot_label="长截图模式",
        dark_screenshot=True,
        focus_crop=(0.58, 0.44, 0.99, 0.98),
        focus_position="bottom_left",
    ),
    PreviewSpec(
        filename="tshot-preview-03-scroll-ocr-pin.png",
        eyebrow="Pinned Capture",
        title="把截图固定在桌面一角",
        subtitle="截图可以直接 Pin 成悬浮窗口，查看参考内容时不必在多个应用之间来回切换。",
        bullets=["单独弹出固定窗口查看截图", "保留系统窗口操作习惯与尺寸调整", "适合对照文档、设计稿和示例代码"],
        accent=(52, 199, 89),
        accent_two=(0, 122, 255),
        screenshot_name="pin.png",
        screenshot_label="Pin 悬浮窗口",
        dark_screenshot=True,
        focus_crop=(0.54, 0.08, 0.98, 0.40),
        focus_position="top_right",
    ),
]


def font(size: int, rounded: bool = False, mono: bool = False) -> ImageFont.FreeTypeFont:
    if mono:
        return ImageFont.truetype(FONT_MONO, size=size)
    if rounded:
        return ImageFont.truetype(FONT_ROUNDED, size=size)
    return ImageFont.truetype(FONT_SANS, size=size)


def wrap_text(text: str, text_font: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    units = list(text)
    lines: list[str] = []
    current = ""
    dummy = Image.new("RGB", (10, 10))
    draw = ImageDraw.Draw(dummy)

    for unit in units:
        candidate = current + unit
        if draw.textlength(candidate, font=text_font) <= max_width or not current:
            current = candidate
        else:
            lines.append(current)
            current = unit

    if current:
        lines.append(current)

    return lines


def draw_multiline(
    draw: ImageDraw.ImageDraw,
    position: tuple[int, int],
    text: str,
    text_font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    max_width: int,
    line_gap: int,
) -> int:
    x, y = position
    lines = wrap_text(text, text_font, max_width)
    bbox = draw.textbbox((0, 0), "国", font=text_font)
    line_height = bbox[3] - bbox[1]

    for line in lines:
        draw.text((x, y), line, font=text_font, fill=fill)
        y += line_height + line_gap

    return y


def rounded_panel(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int, int] | None,
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
    radius: int = 34,
) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def make_gradient_background(spec: PreviewSpec) -> Image.Image:
    width, height = CANVAS_SIZE
    image = Image.new("RGB", CANVAS_SIZE, (10, 12, 20))
    pixels = image.load()

    for y in range(height):
        for x in range(width):
            mix_x = x / width
            mix_y = y / height
            r = int(12 + spec.accent[0] * 0.05 + mix_x * 18 + mix_y * 10)
            g = int(14 + spec.accent[1] * 0.04 + mix_y * 20)
            b = int(24 + spec.accent_two[2] * 0.08 + mix_x * 18)
            pixels[x, y] = (min(r, 255), min(g, 255), min(b, 255))

    glow = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((80, 80, 1320, 1220), fill=spec.accent + (80,))
    glow_draw.ellipse((1480, 140, 2820, 1640), fill=spec.accent_two + (92,))
    glow_draw.ellipse((1600, 920, 2780, 1820), fill=(255, 255, 255, 24))
    glow = glow.filter(ImageFilter.GaussianBlur(140))

    return Image.alpha_composite(image.convert("RGBA"), glow)


def paste_icon(base: Image.Image) -> None:
    icon = Image.open(ICON_PATH).convert("RGBA").resize((112, 112), Image.LANCZOS)
    shadow = Image.new("RGBA", (180, 180), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((22, 26, 158, 162), radius=36, fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    base.alpha_composite(shadow, (148, 124))
    base.alpha_composite(icon, (182, 158))


def draw_copy(draw: ImageDraw.ImageDraw, spec: PreviewSpec) -> None:
    white = (245, 247, 255)
    soft = (179, 188, 212)
    x = 330
    draw.text((x, 150), spec.eyebrow, font=font(44, rounded=True), fill=soft)
    draw.text((x, 220), spec.title, font=font(96, rounded=True), fill=white)
    next_y = draw_multiline(draw, (x, 360), spec.subtitle, font(42), soft, 840, 14)

    bullet_y = next_y + 62
    for bullet in spec.bullets:
        draw.rounded_rectangle((x, bullet_y + 12, x + 26, bullet_y + 38), radius=13, fill=spec.accent)
        draw.text((x + 52, bullet_y - 4), bullet, font=font(36), fill=white)
        bullet_y += 86


def make_round_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(image, size, method=Image.LANCZOS)


def fit_contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = image.copy()
    result.thumbnail(size, Image.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (size[0] - result.width) // 2
    y = (size[1] - result.height) // 2
    canvas.alpha_composite(result, (x, y))
    return canvas


def alpha_composite_rounded(base: Image.Image, image: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    width = box[2] - box[0]
    height = box[3] - box[1]
    resized = image.resize((width, height), Image.LANCZOS) if image.size != (width, height) else image
    clipped = resized.convert("RGBA")
    existing_alpha = clipped.getchannel("A")
    rounded_alpha = make_round_mask((width, height), radius)
    clipped.putalpha(ImageChops.multiply(existing_alpha, rounded_alpha))
    base.alpha_composite(clipped, (box[0], box[1]))


def draw_shadow(base: Image.Image, box: tuple[int, int, int, int], radius: int, alpha: int = 170, blur: int = 32, offset: tuple[int, int] = (0, 18)) -> None:
    shadow = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shadow)
    draw.rounded_rectangle(
        (box[0] + offset[0], box[1] + offset[1], box[2] + offset[0], box[3] + offset[1]),
        radius=radius,
        fill=(0, 0, 0, alpha),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    base.alpha_composite(shadow, (0, 0))


def screenshot_crop(image: Image.Image, crop_box: tuple[float, float, float, float]) -> Image.Image:
    width, height = image.size
    left = int(width * crop_box[0])
    top = int(height * crop_box[1])
    right = int(width * crop_box[2])
    bottom = int(height * crop_box[3])
    return image.crop((left, top, right, bottom))


def add_label(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], text: str, accent: tuple[int, int, int]) -> None:
    label_box = (box[0] + 30, box[1] + 28, box[0] + 260, box[1] + 90)
    rounded_panel(draw, label_box, accent + (240,), radius=22)
    draw.text((label_box[0] + 24, label_box[1] + 14), text, font=font(28, rounded=True), fill=(255, 255, 255))


def render_main_screenshot(base: Image.Image, spec: PreviewSpec) -> None:
    screenshot = Image.open(SCREENSHOT_DIR / spec.screenshot_name).convert("RGBA")
    panel_box = (1100, 150, 2740, 1600)
    draw_shadow(base, panel_box, radius=54, alpha=180, blur=40, offset=(0, 24))

    backdrop = fit_cover(screenshot, (panel_box[2] - panel_box[0], panel_box[3] - panel_box[1])).filter(ImageFilter.GaussianBlur(24))
    overlay_color = (10, 14, 22, 138) if spec.dark_screenshot else (255, 255, 255, 138)
    overlay = Image.new("RGBA", backdrop.size, overlay_color)
    backdrop = Image.alpha_composite(backdrop, overlay)
    alpha_composite_rounded(base, backdrop, panel_box, radius=54)

    panel_draw = ImageDraw.Draw(base)
    rounded_panel(panel_draw, panel_box, None, outline=(255, 255, 255, 70), width=2, radius=54)
    add_label(panel_draw, panel_box, spec.screenshot_label, spec.accent)

    inner_box = (panel_box[0] + 70, panel_box[1] + 110, panel_box[2] - 70, panel_box[3] - 74)
    screenshot_contained = fit_contain(screenshot, (inner_box[2] - inner_box[0], inner_box[3] - inner_box[1]))
    screenshot_draw_box = (
        inner_box[0],
        inner_box[1],
        inner_box[0] + screenshot_contained.width,
        inner_box[1] + screenshot_contained.height,
    )
    draw_shadow(base, screenshot_draw_box, radius=34, alpha=120, blur=20, offset=(0, 14))
    alpha_composite_rounded(base, screenshot_contained, screenshot_draw_box, radius=34)
    rounded_panel(panel_draw, screenshot_draw_box, None, outline=(255, 255, 255, 120), width=2, radius=34)

    if spec.focus_crop is None:
        return

    focus = screenshot_crop(screenshot, spec.focus_crop)
    focus_box = focus_box_for(spec.focus_position)
    draw_shadow(base, focus_box, radius=30, alpha=150, blur=24, offset=(0, 16))
    focus_backdrop = fit_cover(focus, (focus_box[2] - focus_box[0], focus_box[3] - focus_box[1]))
    alpha_composite_rounded(base, focus_backdrop, focus_box, radius=30)
    rounded_panel(panel_draw, focus_box, (255, 255, 255, 0), outline=spec.accent + (255,), width=4, radius=30)


def focus_box_for(position: str) -> tuple[int, int, int, int]:
    if position == "bottom_left":
        return (1180, 1170, 1740, 1490)
    if position == "top_right":
        return (2000, 220, 2640, 580)
    return (2000, 1180, 2640, 1520)


def create_preview(spec: PreviewSpec) -> Image.Image:
    base = make_gradient_background(spec)
    paste_icon(base)
    draw = ImageDraw.Draw(base)
    draw_copy(draw, spec)
    render_main_screenshot(base, spec)
    draw.text((188, 1660), "Mac App Store Preview · 2880 × 1800", font=font(24, mono=True), fill=(153, 162, 185))
    return base.convert("RGB")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for spec in SPECS:
        image = create_preview(spec)
        image.save(OUTPUT_DIR / spec.filename, quality=96)
        print(f"Generated {spec.filename}")


if __name__ == "__main__":
    main()
