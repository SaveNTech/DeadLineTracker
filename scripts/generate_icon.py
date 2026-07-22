"""Generates the DeadlineTracker app icon: an indigo background with a white
flame (the app's established visual motif — see the login screen and the
"overdue" treatment throughout the app). Produces two files:

  mobile/assets/icon/icon.png             - full icon, opaque background
  mobile/assets/icon/icon_foreground.png  - flame only, transparent background
                                             (Android adaptive icon foreground)

Run once locally; flutter_launcher_icons consumes these to generate all the
platform-specific launcher icon sizes.
"""

import math

from PIL import Image, ImageDraw

SIZE = 1024
PRIMARY = (91, 95, 239, 255)  # AppColors.primary #5B5FEF
WHITE = (255, 255, 255, 255)
TRANSPARENT = (0, 0, 0, 0)

Point = tuple[float, float]


def _bump(t: float, peak: float, half_width: float, amplitude: float) -> float:
    """A raised-cosine bump: 0 outside [peak-half_width, peak+half_width],
    rising smoothly to `amplitude` at `peak`. Touches zero with zero slope,
    so it blends into a taper without leaving a visible kink."""
    d = abs(t - peak)
    if d >= half_width:
        return 0.0
    return amplitude * 0.5 * (1 + math.cos(math.pi * d / half_width))


def _right_edge(t: float) -> float:
    """x offset of the right boundary, t=0 at base, t=1 at tip: a taper with a
    subtle outward puff low down, giving the silhouette gentle wave instead of
    a straight sail-like edge."""
    taper = 34 * (1 - t**0.6)
    return taper + _bump(t, 0.20, 0.24, 9)


def _left_edge(t: float) -> float:
    """x offset (negative) of the left boundary: the same taper as the right
    side plus one big outward "lick" bulge — the classic asymmetric flame
    silhouette."""
    taper = 34 * (1 - t**0.6)
    return -(taper + _bump(t, 0.34, 0.34, 27))


def flame_outline(steps: int = 160) -> list[Point]:
    """Builds a simple (non-self-intersecting) closed flame silhouette by
    walking up the right boundary from base to tip, then back down the left
    boundary from tip to base — each boundary expressed as x(y), which
    guarantees the two halves never cross."""
    y_base, y_tip = 0.0, -100.0
    pts: list[Point] = []
    for i in range(steps + 1):
        t = i / steps
        y = y_base + (y_tip - y_base) * t
        pts.append((_right_edge(t), y))
    for i in range(steps + 1):
        t = 1 - i / steps
        y = y_base + (y_tip - y_base) * t
        pts.append((_left_edge(t), y))
    return pts


def supersampled_flame(size: int, fill, bg) -> Image.Image:
    ss = 4
    canvas = size * ss
    big = Image.new("RGBA", (canvas, canvas), bg)
    draw = ImageDraw.Draw(big)

    cx, cy = canvas / 2, canvas * 0.80  # cy = pixel row of the flame's base (y=0)
    scale = canvas * 0.0068  # local coords (100 units tall, base to tip) -> canvas pixels
    pts = [(cx + x * scale, cy + y * scale) for x, y in flame_outline()]
    draw.polygon(pts, fill=fill)
    return big.resize((size, size), Image.LANCZOS)


def main() -> None:
    full = Image.new("RGBA", (SIZE, SIZE), TRANSPARENT)
    draw = ImageDraw.Draw(full)
    pad = int(SIZE * 0.04)
    radius = int(SIZE * 0.22)
    draw.rounded_rectangle([pad, pad, SIZE - pad, SIZE - pad], radius=radius, fill=PRIMARY)
    full.alpha_composite(supersampled_flame(SIZE, WHITE, TRANSPARENT))
    full.save("mobile/assets/icon/icon.png")

    # Foreground-only (transparent bg) for Android adaptive icons.
    supersampled_flame(SIZE, WHITE, TRANSPARENT).save("mobile/assets/icon/icon_foreground.png")

    print("Wrote mobile/assets/icon/icon.png and icon_foreground.png")


if __name__ == "__main__":
    main()
