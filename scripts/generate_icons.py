"""
Generate Solar Amber branded PWA icons for AiBlojka.

Design:
  - Background: #0E0C08 (near-black)
  - Letter "A" with serifs in #FFD54F (amber)
  - Outer glow in #FF8F00 (orange) via Gaussian blur layers
  - Maskable variant: same design, guaranteed safe-zone clearance

Run from project root:
    .venv-icons/bin/python3 scripts/generate_icons.py
"""

import math
import os
from PIL import Image, ImageDraw, ImageFilter

# ---------------------------------------------------------------------------
# Palette
# ---------------------------------------------------------------------------

BG = (14, 12, 8)          # #0E0C08
AMBER = (255, 213, 79)     # #FFD54F
GLOW = (255, 143, 0)       # #FF8F00

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------


def _thick_line(draw: ImageDraw.ImageDraw, x1, y1, x2, y2, width, color):
    """Draw a filled parallelogram representing a thick line segment."""
    dx = x2 - x1
    dy = y2 - y1
    length = math.hypot(dx, dy)
    if length == 0:
        return
    px = -dy / length * width / 2
    py = dx / length * width / 2
    pts = [
        (x1 + px, y1 + py),
        (x1 - px, y1 - py),
        (x2 - px, y2 - py),
        (x2 + px, y2 + py),
    ]
    draw.polygon(pts, fill=color)


def _create_icon(size: int, maskable: bool = False) -> Image.Image:
    scale = size / 512.0

    # Content padding — maskable icons need extra clearance (80 % safe zone)
    pad = int(size * 0.18) if maskable else int(size * 0.10)

    cx = size // 2

    top_y = pad
    bottom_y = size - pad
    left_x = pad
    right_x = size - pad

    stroke = max(int(52 * scale), 6)

    # -----------------------------------------------------------------------
    # Build the "A" shape on a transparent layer
    # -----------------------------------------------------------------------
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    amber_fill = AMBER + (255,)

    # Left leg: apex → bottom-left
    _thick_line(draw, cx, top_y, left_x, bottom_y, stroke, amber_fill)
    # Right leg: apex → bottom-right
    _thick_line(draw, cx, top_y, right_x, bottom_y, stroke, amber_fill)

    # Crossbar at ~52 % of the vertical span
    t = 0.52
    cross_y = int(top_y + (bottom_y - top_y) * t)
    # X positions where the legs sit at cross_y
    cl_x = int(cx + (left_x - cx) * t)
    cr_x = int(cx + (right_x - cx) * t)
    cb_h = max(int(stroke * 0.72), 4)
    draw.rectangle([cl_x, cross_y - cb_h // 2, cr_x, cross_y + cb_h // 2], fill=amber_fill)

    # Bottom serifs
    sw = max(int(44 * scale), 5)
    sh = max(int(18 * scale), 3)
    draw.rectangle([left_x - sw // 2, bottom_y - sh, left_x + sw // 2, bottom_y], fill=amber_fill)
    draw.rectangle([right_x - sw // 2, bottom_y - sh, right_x + sw // 2, bottom_y], fill=amber_fill)

    # -----------------------------------------------------------------------
    # Glow: blur the layer, tint orange, composite multiple passes
    # -----------------------------------------------------------------------
    # Re-colour the glow source to the orange glow colour
    r, g, b, a = layer.split()
    gr = r.point(lambda i: GLOW[0] if i > 0 else 0)
    gg = g.point(lambda i: GLOW[1] if i > 0 else 0)
    gb = b.point(lambda i: GLOW[2] if i > 0 else 0)
    glow_src = Image.merge("RGBA", (gr, gg, gb, a))

    base = Image.new("RGBA", (size, size), BG + (255,))

    for radius in (int(10 * scale), int(20 * scale), int(36 * scale)):
        blurred = glow_src.filter(ImageFilter.GaussianBlur(radius=max(radius, 1)))
        base = Image.alpha_composite(base, blurred)

    # Composite the sharp amber "A" on top
    base = Image.alpha_composite(base, layer)

    return base.convert("RGB")


# ---------------------------------------------------------------------------
# Output configuration
# ---------------------------------------------------------------------------

OUTPUTS = [
    ("web/icons/Icon-192.png",          192, False),
    ("web/icons/Icon-512.png",          512, False),
    ("web/icons/Icon-maskable-192.png", 192, True),
    ("web/icons/Icon-maskable-512.png", 512, True),
    ("web/favicon.png",                  64, False),
]


def main():
    root = os.path.join(os.path.dirname(__file__), "..")
    for rel_path, size, maskable in OUTPUTS:
        out_path = os.path.normpath(os.path.join(root, rel_path))
        img = _create_icon(size, maskable)
        img.save(out_path, "PNG", optimize=True)
        print(f"  {out_path}  ({size}×{size}{'  maskable' if maskable else ''})")
    print("Done.")


if __name__ == "__main__":
    main()
