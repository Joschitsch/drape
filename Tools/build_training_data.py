#!/usr/bin/env python3
"""
build_training_data.py — Drape offline tooling (NOT part of the app target)

Builds Create ML `labeledDirectories` trees for the on-device garment classifiers
and writes the MODEL_CARD.md provenance entry up front (dataset, license, class
histogram), so training-data origins are recorded as the data is built — not
reconstructed at release. Tools/train_classifier.swift consumes the trees and
appends the held-out accuracy to the same card.

Output layout (per axis):

    <out>/category/{train,validation,test}/<class>/<image>.jpg
    <out>/pattern/{train,validation,test}/<class>/<image>.jpg
    <out>/<axis>/eval/<class>/<image>.jpg      # iMaterialist, eval-only

Data sources and licenses (shipping models train ONLY on permissive data):
  • category : Kaggle Fashion Product Images (MIT)            → train/val/test
  • pattern  : Fashionpedia (CC-BY), via the app's DEBUG export → train/val/test
  • eval     : iMaterialist — EVAL/TUNING ONLY, never in train/ (license is
               research-oriented; keep it out of shipped weights)

Class vocabulary: every category folder name is a label that
`VisionGarmentClassifier.properties(for:)` already recognizes, so the model's
prediction flows straight into the existing warmth/formality/seasons table with
no Swift change. Pattern folder names are the `PatternType` raw values.

Requirements:  pip install pandas pillow

Usage:
    python3 Tools/build_training_data.py \
        --kaggle-root   /path/to/fashion-product-images-small \
        --pattern-dir   /path/to/pattern-training \
        --out           Tools/data/training \
        [--imaterialist-root /path/to/imaterialist_by_class] \
        [--max-per-class 3000] [--floor 300] \
        [--model-card Tools/MODEL_CARD.md]

  --kaggle-root  contains styles.csv and images/<id>.jpg
  --pattern-dir  the Documents/pattern-training folder the app's harness exported
                 (images/ + pattern-labels.csv)
  --imaterialist-root  OPTIONAL; pre-arranged <class>/<image>.jpg where <class>
                 already matches our category or PatternType labels (eval only)
"""

from __future__ import annotations

import argparse
import csv
import datetime
import json
import shutil
from collections import Counter, defaultdict
from pathlib import Path

try:
    import pandas as pd
except ImportError:  # pragma: no cover - guidance only
    raise SystemExit("Missing dependency: pip install pandas pillow")
from PIL import Image, ImageDraw, ImageEnhance

# ── Reproducible split (mirrors StableHash.fnv1a in DebugWardrobeImporter) ──────
FNV_OFFSET = 0xCBF29CE484222325
FNV_PRIME = 0x100000001B3
MASK64 = (1 << 64) - 1


def fnv1a(s: str) -> int:
    h = FNV_OFFSET
    for b in s.encode("utf-8"):
        h ^= b
        h = (h * FNV_PRIME) & MASK64
    return h


def split_for(dataset_id: str, item_id: str, val_frac: float, test_frac: float) -> str:
    """Deterministic train/validation/test bucket keyed by dataset + id, using the
    same fnv1a("{dataset}/{id}") % 100 scheme as the in-app harness."""
    bucket = fnv1a(f"{dataset_id}/{item_id}") % 100
    test_cut = test_frac * 100
    val_cut = test_cut + val_frac * 100
    if bucket < test_cut:
        return "test"
    if bucket < val_cut:
        return "validation"
    return "train"


# ── Canonical category vocabulary ──────────────────────────────────────────────
# Kaggle `articleType` → canonical label. Every value below is a string that
# `properties(for:)` keys on, so no Swift change is needed to consume it.
KAGGLE_ARTICLE_TO_CANONICAL = {
    "Tshirts": "t-shirt",
    "Shirts": "shirt",
    "Tops": "blouse",
    "Blouse": "blouse",
    "Sweaters": "sweater",
    "Sweatshirts": "sweatshirt",
    "Tank": "tank",
    "Tunics": "blouse",
    "Jackets": "jacket",
    "Blazers": "blazer",
    "Rain Jacket": "jacket",
    "Jeans": "jeans",
    "Trousers": "trousers",
    "Track Pants": "trousers",
    "Shorts": "shorts",
    "Skirts": "skirt",
    "Capris": "trousers",
    "Leggings": "leggings",
    "Dresses": "dress",
    "Jumpsuit": "jumpsuit",
    "Casual Shoes": "sneaker",
    "Sports Shoes": "sneaker",
    "Sneakers": "sneaker",
    "Flip Flops": "sandal",
    "Sandals": "sandal",
    "Heels": "high heel",
    "Formal Shoes": "loafer",
    "Flats": "loafer",
    "Handbags": "handbag",
    "Backpacks": "backpack",
    "Clutches": "handbag",
    "Caps": "cap",
    "Hat": "hat",
    "Sunglasses": "sunglasses",
    "Scarves": "scarf",
    "Ties": "tie",
    "Belts": "belt",
}

KAGGLE_URL = "https://www.kaggle.com/datasets/paramaggarwal/fashion-product-images-small"
FASHIONPEDIA_URL = "https://github.com/cvdfoundation/fashionpedia"
CLOTHING_URL = "https://www.kaggle.com/datasets/agrigorev/clothing-dataset-full"

# Clothing Dataset (full, CC0) — real individual-garment photos, no on-model
# shots, so it matches Drape's isolated-garment deployment domain (unlike Kaggle
# catalog data). `images.csv` has columns image,sender_id,label,kids. Map its 20
# labels to canonical labels that `properties(for:)` recognizes; drop the junk
# labels ("Not sure"/"Other"/"Skip") and ambiguous "Body".
CLOTHING_LABEL_TO_CANONICAL = {
    "T-Shirt": "t-shirt", "Longsleeve": "longsleeve", "Shirt": "shirt",
    "Polo": "polo shirt", "Undershirt": "tank", "Hoodie": "hoodie",
    "Top": "blouse", "Blouse": "blouse",
    "Pants": "trousers", "Shorts": "shorts", "Skirt": "skirt",
    "Dress": "dress", "Outwear": "outwear", "Blazer": "blazer",
    "Shoes": "shoe", "Hat": "hat",
}

# Per-class image caps that shape the model's *prior* to match a real wardrobe.
# Kaggle is catalog data — ~half bags/shoes/accessories — so an unweighted model
# learns an "it's probably a bag" reflex and confidently calls isolated tops
# "backpack"/"handbag". A closet is mostly garments, so we starve the accessory
# classes (especially bags) and let garment classes dominate. Anything not listed
# uses --max-per-class. The matching deployment prior also helps accuracy.
CLASS_CAP = {
    # bags — the worst offenders; keep just enough to still recognize a real bag
    "handbag": 120, "backpack": 120,
    # other accessories — minor in a real wardrobe
    "sunglasses": 120, "belt": 120, "tie": 120, "scarf": 120, "cap": 120, "hat": 60,
    # footwear — already classifies well via its own path; modest is plenty
    "sneaker": 500, "sandal": 400, "loafer": 400, "high heel": 400,
    # tops are hugely over-represented in Kaggle; cap them so they don't swamp
    # the smaller garment categories (bottoms/dress/outerwear) and pull them in.
    "t-shirt": 1200, "shirt": 1200, "blouse": 1000,
}


def jpeg_save(src: Path, dst: Path, flip: bool = False, brightness: float = 1.0) -> bool:
    """Copy/convert one image into the tree, optionally augmented. Returns False
    when the source can't be read (skipped, not fatal)."""
    try:
        if not flip and brightness == 1.0 and src.suffix.lower() in (".jpg", ".jpeg"):
            shutil.copyfile(src, dst)
            return True
        img = Image.open(src).convert("RGB")
        if flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        if brightness != 1.0:
            img = ImageEnhance.Brightness(img).enhance(brightness)
        img.save(dst, "JPEG", quality=92)
        return True
    except Exception as exc:  # noqa: BLE001 - report and skip
        print(f"  skip {src.name}: {exc}")
        return False


def write_split(
    axis: str,
    dataset_id: str,
    samples: list[tuple[str, str, Path]],  # (class, item_id, source_path)
    out_root: Path,
    max_per_class: int,
    floor: int,
    val_frac: float,
    test_frac: float,
) -> Counter:
    """Writes a balanced train/val/test tree for one axis. Caps each class at
    max_per_class and oversamples (flip + brightness jitter) train-split minority
    classes up to `floor`. Returns the final per-class histogram across splits."""
    by_class: dict[str, list[tuple[str, Path]]] = defaultdict(list)
    for cls, item_id, path in samples:
        by_class[cls].append((item_id, path))

    final = Counter()
    for cls, rows in sorted(by_class.items()):
        cap = CLASS_CAP.get(cls, max_per_class)
        rows = sorted(rows)[:cap]  # deterministic, prior-shaping cap
        train_rows: list[tuple[str, Path]] = []
        for item_id, path in rows:
            bucket = split_for(dataset_id, item_id, val_frac, test_frac)
            dst_dir = out_root / axis / bucket / cls
            dst_dir.mkdir(parents=True, exist_ok=True)
            if jpeg_save(path, dst_dir / f"{item_id}.jpg"):
                final[cls] += 1
                if bucket == "train":
                    train_rows.append((item_id, path))

        # Oversample only the train split, so val/test stay honest. Never inflate a
        # capped class past its cap, or we'd re-introduce the prior we just removed.
        target = min(floor, cap)
        i = 0
        while train_rows and len(train_rows) + i < target and i < target:
            item_id, path = train_rows[i % len(train_rows)]
            n = i // len(train_rows) + 1
            dst = out_root / axis / "train" / cls / f"{item_id}_aug{n}.jpg"
            jpeg_save(path, dst, flip=(n % 2 == 1), brightness=1.0 + 0.08 * ((n % 3) - 1))
            i += 1
    return final


def collect_kaggle(root: Path) -> list[tuple[str, str, Path]]:
    styles = root / "styles.csv"
    images = root / "images"
    if not styles.exists():
        raise SystemExit(f"styles.csv not found at {styles}")
    df = pd.read_csv(styles, on_bad_lines="skip")
    out: list[tuple[str, str, Path]] = []
    for row in df.itertuples(index=False):
        article = str(getattr(row, "articleType", "")).strip()
        cls = KAGGLE_ARTICLE_TO_CANONICAL.get(article)
        if not cls:
            continue
        img = images / f"{int(row.id)}.jpg"
        if img.exists():
            out.append((cls, str(int(row.id)), img))
    return out


def collect_clothing(root: Path) -> list[tuple[str, str, Path]]:
    """Clothing Dataset (full, CC0): images.csv + images_compressed/<uuid>.jpg."""
    csv_path = root / "images.csv"
    if not csv_path.exists():
        raise SystemExit(f"images.csv not found at {csv_path}")
    images = root / "images_compressed"
    if not images.exists():
        images = root / "images_original"
    df = pd.read_csv(csv_path)
    out: list[tuple[str, str, Path]] = []
    for row in df.itertuples(index=False):
        cls = CLOTHING_LABEL_TO_CANONICAL.get(str(row.label).strip())
        if not cls:
            continue
        img = images / f"{row.image}.jpg"
        if img.exists():
            out.append((cls, str(row.image), img))
    return out


# Neutral canvas matching VisionImageProcessingService.canvasColor (0.95,0.95,0.97).
FP_CANVAS_RGB = (242, 242, 247)


def fashionpedia_pattern_type(names: list[str]) -> str | None:
    """Fashionpedia textile-pattern attribute names → PatternType raw value.
    Ported from `FashionpediaAttributeMap.patternType` (Swift). MEASUREMENT-ONLY
    use, so a parallel copy here is acceptable; do not reuse for a shipped model."""
    low = [n.lower() for n in names]

    def has(*keys: str) -> bool:
        return any(any(k in n for k in keys) for n in low)

    if has("floral", "flower"): return "floral"
    if has("stripe", "pinstripe"): return "stripe"
    if has("check", "plaid", "tartan", "gingham", "houndstooth", "windowpane", "argyle"): return "check"
    if has("graphic", "letters", "numbers", "logo", "cartoon", "text", "print"): return "graphic"
    if has("paisley", "geometric", "abstract", "animal", "leopard", "camouflage",
           "camo", "polka", "dot", "tie-dye", "tie dye"): return "abstract"
    if has("plain", "no pattern", "solid"): return "solid"
    return None


def _fp_cutout(img_path: Path, bbox: list[float], polygons: list) -> "Image.Image | None":
    """Polygon-cut one garment onto the neutral canvas, cropped to its bbox —
    mirrors FashionpediaCocoSource.garmentCutout so the model sees app-like input."""
    try:
        img = Image.open(img_path).convert("RGB")
    except Exception:
        return None
    w_img, h_img = img.size
    x = max(0, int(bbox[0])); y = max(0, int(bbox[1]))
    w = int(min(bbox[2], w_img - x)); h = int(min(bbox[3], h_img - y))
    if w < 8 or h < 8:
        return None
    mask = Image.new("L", (w_img, h_img), 0)
    draw = ImageDraw.Draw(mask)
    drew = False
    for poly in polygons:
        if isinstance(poly, list) and len(poly) >= 6:
            draw.polygon(list(zip(poly[0::2], poly[1::2])), fill=255)
            drew = True
    if not drew:
        return None
    canvas = Image.new("RGB", (w_img, h_img), FP_CANVAS_RGB)
    canvas.paste(img, (0, 0), mask)
    return canvas.crop((x, y, x + w, y + h))


def collect_fashionpedia_coco(json_path: Path, images_dir: Path,
                              stage_dir: Path) -> list[tuple[str, str, Path]]:
    """Read Fashionpedia COCO directly: for each single-pattern garment annotation
    with a polygon, cut it onto the canvas and stage a PNG. MEASUREMENT-ONLY."""
    coco = json.loads(json_path.read_text())
    file_by_id = {im["id"]: im["file_name"] for im in coco["images"]}
    attr_name = {a["id"]: a["name"] for a in coco["attributes"]}
    stage_dir.mkdir(parents=True, exist_ok=True)
    out: list[tuple[str, str, Path]] = []
    for ann in sorted(coco["annotations"], key=lambda a: a["id"]):
        seg = ann.get("segmentation")
        if not isinstance(seg, list) or not seg:   # skip RLE (dict) / empty
            continue
        names = [attr_name[i] for i in (ann.get("attribute_ids") or []) if i in attr_name]
        pattern = fashionpedia_pattern_type(names)
        if not pattern:
            continue
        fn = file_by_id.get(ann["image_id"])
        if not fn:
            continue
        cut = _fp_cutout(images_dir / fn, ann["bbox"], seg)
        if cut is None:
            continue
        dst = stage_dir / f"{ann['id']:07d}.png"
        cut.save(dst)
        out.append((pattern, str(ann["id"]), dst))
    return out


def collect_pattern(pattern_dir: Path) -> list[tuple[str, str, Path]]:
    csv_path = pattern_dir / "pattern-labels.csv"
    images = pattern_dir / "images"
    if not csv_path.exists():
        raise SystemExit(f"pattern-labels.csv not found at {csv_path} (run the app's "
                         "harness: Fashionpedia → Export pattern training data)")
    out: list[tuple[str, str, Path]] = []
    with csv_path.open() as fh:
        for r in csv.DictReader(fh):
            img = images / r["filename"]
            if img.exists():
                out.append((r["patternType"], Path(r["filename"]).stem, img))
    return out


def collect_eval_dir(root: Path) -> list[tuple[str, str, Path]]:
    """iMaterialist pre-arranged as <class>/<image> — copied verbatim to eval/."""
    out: list[tuple[str, str, Path]] = []
    for cls_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        for img in sorted(cls_dir.glob("*")):
            if img.suffix.lower() in (".jpg", ".jpeg", ".png"):
                out.append((cls_dir.name, img.stem, img))
    return out


def write_eval(axis: str, samples: list[tuple[str, str, Path]], out_root: Path) -> Counter:
    final = Counter()
    for cls, item_id, path in samples:
        dst_dir = out_root / axis / "eval" / cls
        dst_dir.mkdir(parents=True, exist_ok=True)
        if jpeg_save(path, dst_dir / f"{item_id}.jpg"):
            final[cls] += 1
    return final


def write_model_card(card: Path, axis: str, dataset: str, url: str, license_: str,
                     histogram: Counter) -> None:
    stamp = datetime.date.today().isoformat()
    lines = [f"\n## {axis} model — data provenance ({stamp})\n",
             f"- Dataset: {dataset}", f"- URL: {url}", f"- License: {license_}",
             f"- Classes ({len(histogram)}): {', '.join(sorted(histogram))}",
             "- Per-class histogram:"]
    for cls, n in sorted(histogram.items(), key=lambda kv: -kv[1]):
        lines.append(f"    - {cls}: {n}")
    card.parent.mkdir(parents=True, exist_ok=True)
    with card.open("a") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"Provenance → {card}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--clothing-root", type=Path,
                    help="Clothing Dataset full root (images.csv + images_compressed/) — CC0, in-domain")
    ap.add_argument("--kaggle-root", type=Path, help="Fashion Product Images root (styles.csv + images/)")
    ap.add_argument("--pattern-dir", type=Path, help="app DEBUG export (images/ + pattern-labels.csv)")
    ap.add_argument("--fashionpedia-coco", type=Path,
                    help="Fashionpedia instances_attributes JSON — pattern, MEASUREMENT-ONLY (images not shippable)")
    ap.add_argument("--fashionpedia-images", type=Path, help="Fashionpedia images dir matching the JSON")
    ap.add_argument("--imaterialist-root", type=Path, help="EVAL-ONLY <class>/<image> tree")
    ap.add_argument("--out", type=Path, required=True, help="output root for the Create ML trees")
    ap.add_argument("--model-card", type=Path, default=Path("Tools/MODEL_CARD.md"))
    ap.add_argument("--max-per-class", type=int, default=3000)
    ap.add_argument("--floor", type=int, default=300, help="min train images/class (oversampled)")
    ap.add_argument("--val-frac", type=float, default=0.10)
    ap.add_argument("--test-frac", type=float, default=0.10)
    args = ap.parse_args()

    if args.clothing_root:
        print("Category: collecting Clothing Dataset (full, CC0)…")
        hist = write_split("category", "clothing-dataset-full", collect_clothing(args.clothing_root),
                           args.out, args.max_per_class, args.floor, args.val_frac, args.test_frac)
        print(f"  category classes: {dict(hist)}")
        write_model_card(args.model_card, "category", "Clothing Dataset (full, high resolution)",
                         CLOTHING_URL, "CC0", hist)

    if args.kaggle_root:
        print("Category: collecting Kaggle Fashion Product Images…")
        hist = write_split("category", "fashion-product-images", collect_kaggle(args.kaggle_root),
                           args.out, args.max_per_class, args.floor, args.val_frac, args.test_frac)
        print(f"  category classes: {dict(hist)}")
        write_model_card(args.model_card, "category", "Kaggle Fashion Product Images",
                         KAGGLE_URL, "MIT", hist)

    if args.pattern_dir:
        print("Pattern: collecting Fashionpedia DEBUG export…")
        hist = write_split("pattern", "fashionpedia", collect_pattern(args.pattern_dir),
                           args.out, args.max_per_class, args.floor, args.val_frac, args.test_frac)
        print(f"  pattern classes: {dict(hist)}")
        write_model_card(args.model_card, "pattern", "Fashionpedia (DEBUG isolated cutouts)",
                         FASHIONPEDIA_URL, "CC-BY 4.0", hist)

    if args.fashionpedia_coco:
        print("Pattern: cutting Fashionpedia garments directly (MEASUREMENT-ONLY — not shippable)…")
        samples = collect_fashionpedia_coco(args.fashionpedia_coco, args.fashionpedia_images,
                                            args.out / "_fp_stage")
        print(f"  cut {len(samples)} single-pattern garments")
        hist = write_split("pattern", "fashionpedia", samples,
                           args.out, args.max_per_class, args.floor, args.val_frac, args.test_frac)
        print(f"  pattern classes: {dict(hist)}")
        write_model_card(args.model_card,
                         "pattern (MEASUREMENT-ONLY — Fashionpedia images are not license-clear for a shipped model)",
                         "Fashionpedia val2020 (polygon cutouts)", FASHIONPEDIA_URL,
                         "annotations CC-BY 4.0; images mixed-source, local measurement only", hist)

    if args.imaterialist_root:
        print("Eval: collecting iMaterialist (eval/tuning only)…")
        samples = collect_eval_dir(args.imaterialist_root)
        # Route by whether class names look like PatternType or category labels.
        pattern_labels = {"solid", "stripe", "check", "floral", "abstract", "graphic"}
        axis = "pattern" if any(c in pattern_labels for c, _, _ in samples) else "category"
        hist = write_eval(axis, samples, args.out)
        print(f"  iMaterialist eval/{axis} classes: {dict(hist)}")
        print("  (eval-only — NOT added to train/, per its research license)")

    print("Done. Train with: swift Tools/train_classifier.swift <axis> "
          f"{args.out}/<axis> <out.mlmodel> {args.model_card}")


if __name__ == "__main__":
    main()
