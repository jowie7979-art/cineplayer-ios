"""Maakt het CinePlayer-appicoon (1024x1024): zwart met goud, C-monogram met afspeelknop."""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

S = 4096  # tekenen op 4x, daarna verkleinen voor zachte randen
C = S / 2


def radiaal(binnen, buiten, straal, midden=(C, C)):
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    d = np.sqrt((x - midden[0]) ** 2 + (y - midden[1]) ** 2) / straal
    t = np.clip(d, 0, 1)[..., None] ** 1.4
    return (np.array(binnen) * (1 - t) + np.array(buiten) * t).astype(np.float32)


def goud():
    """Geborsteld goud: diagonaal verloop met een lichte glansband."""
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    t = (x * 0.55 + y * 0.45) / S  # 0 linksboven, 1 rechtsonder
    stops = [
        (0.00, (250, 232, 180)),
        (0.30, (214, 182, 116)),
        (0.48, (150, 112, 56)),
        (0.58, (238, 214, 156)),
        (0.75, (190, 152, 88)),
        (1.00, (118, 86, 40)),
    ]
    rgb = np.zeros((S, S, 3), np.float32)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        m = (t >= t0) & (t <= t1)
        f = ((t - t0) / (t1 - t0))[m][:, None]
        rgb[m] = np.array(c0) * (1 - f) + np.array(c1) * f
    # fijne borstelstreep
    rng = np.random.default_rng(7)
    streep = rng.normal(0, 1, (S, 1)).astype(np.float32)
    streep = np.repeat(streep, S, axis=1)
    rgb += streep[..., None] * 3.0
    return np.clip(rgb, 0, 255)


def masker(teken):
    m = Image.new("L", (S, S), 0)
    teken(ImageDraw.Draw(m))
    return m


def boog(d, r, dikte, van, tot):
    d.arc([C - r, C - r, C + r, C + r], van, tot, fill=255, width=int(dikte))


def main(uit: Path):
    # achtergrond: warm zwart met licht in het midden
    bg = radiaal((44, 34, 24), (6, 6, 10), S * 0.72, midden=(C, C * 0.92))
    rng = np.random.default_rng(3)
    bg += rng.normal(0, 1.6, (S, S, 1)).astype(np.float32)  # filmkorrel
    beeld = Image.fromarray(np.clip(bg, 0, 255).astype(np.uint8), "RGB")

    goudlaag = Image.fromarray(goud().astype(np.uint8), "RGB")

    # C-monogram: dikke boog, open aan de rechterkant, schuin afgesneden
    r_c, dikte_c = S * 0.255, S * 0.062
    c_m = masker(lambda d: boog(d, r_c, dikte_c, 52, 308))

    # afspeelknop met afgeronde hoeken, tip steekt in de opening van de C
    def driehoek(d):
        h = S * 0.235
        b = h * 1.12
        x0 = C - b * 0.36
        pts = [(x0, C - h / 2), (x0, C + h / 2), (x0 + b, C)]
        d.polygon(pts, fill=255)
    p_m = masker(driehoek).filter(ImageFilter.GaussianBlur(S * 0.006))
    p_m = p_m.point(lambda v: 255 if v > 150 else 0)  # rondt de hoeken af

    # dunne buitenring + binnenring als haarlijnen
    ring_m = masker(lambda d: boog(d, S * 0.355, S * 0.006, 0, 360))
    ring2_m = masker(lambda d: boog(d, S * 0.335, S * 0.0022, 0, 360))

    # zachte gouden gloed achter het monogram
    gloed = Image.new("RGB", (S, S), (200, 160, 90))
    gloed_m = Image.composite(c_m, p_m, c_m).filter(ImageFilter.GaussianBlur(S * 0.05))
    gloed_m = gloed_m.point(lambda v: int(v * 0.35))
    beeld = Image.composite(gloed, beeld, gloed_m)

    # slagschaduw voor diepte
    schaduw_m = Image.composite(c_m, p_m, c_m)
    schaduw_m = schaduw_m.transform((S, S), Image.AFFINE, (1, 0, -S * 0.006, 0, 1, -S * 0.012))
    schaduw_m = schaduw_m.filter(ImageFilter.GaussianBlur(S * 0.012)).point(lambda v: int(v * 0.7))
    beeld = Image.composite(Image.new("RGB", (S, S), (0, 0, 0)), beeld, schaduw_m)

    beeld = Image.composite(goudlaag, beeld, ring_m.point(lambda v: int(v * 0.85)))
    beeld = Image.composite(goudlaag, beeld, ring2_m.point(lambda v: int(v * 0.45)))
    beeld = Image.composite(goudlaag, beeld, c_m)
    beeld = Image.composite(goudlaag, beeld, p_m)

    # vier kleine ruiten op de buitenring (noord/oost/zuid/west)
    def ruiten(d):
        r, k = S * 0.355, S * 0.016
        for a in (0, 90, 180, 270):
            x = C + r * math.cos(math.radians(a))
            y = C + r * math.sin(math.radians(a))
            d.polygon([(x, y - k), (x + k, y), (x, y + k), (x - k, y)], fill=255)
    beeld = Image.composite(goudlaag, beeld, masker(ruiten))

    beeld.resize((1024, 1024), Image.LANCZOS).save(uit, optimize=True)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
