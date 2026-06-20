# GarmentCategoryClassifier.mlmodel — model card

On-device image classifier that predicts a garment's fine-grained class, mapped
to Drape's `GarmentCategory` at runtime via `DatasetLabelMap`.

## Provenance & license
- **Training data:** [clothing-dataset-small](https://github.com/alexeygrigorev/clothing-dataset-small)
  by Alexey Grigorev — **CC0 / public domain**. Safe to train a *shipped* model on.
- **Method:** Create ML transfer learning (`MLImageClassifier`, default Vision
  feature extractor). See `Tools/train_category_model.swift`.

## Classes (10, = dataset folder names)
dress, hat, longsleeve, outwear, pants, shirt, shoes, shorts, skirt, t-shirt
→ collapsed to Drape's six categories by `DatasetLabelMap.category(forArticleType:)`.

## Measured accuracy (fine-grained, 10-class)
- Held-out validation: ~80%   ·   Held-out test: ~82%
(Coarse `GarmentCategory` accuracy is higher, since e.g. t-shirt/shirt/longsleeve
all collapse to `top`.) Baseline before the model — generic `VNClassifyImageRequest`
— was 38% accuracy / 77% coverage on device.

## Integration
`VisionGarmentClassifier.modelMatch(cgImage:)` runs the model first; its top
prediction (confidence ≥ 0.5) becomes the category source, with the generic Vision
label heuristic as fallback when the model is unsure or absent.

## ⚠️ Verify on a real device, not the Simulator
Create ML image classifiers use Apple's `scenePrint` feature extractor — an
OS-provided model that is **not present in the iOS Simulator runtime**. The model
*loads* on the Simulator but produces no predictions there (so the harness shows
category coverage 0% on Simulator), exactly like `VNClassifyImageRequest`. On a
physical device the feature extractor is available and the model runs. Measure
category accuracy on-device via the harness.

## Retrain
```
swift Tools/train_category_model.swift ~/clothing-dataset-small \
  drape/Services/Classification/GarmentCategoryClassifier.mlmodel
```
~148 KB output; the app build compiles it to `.mlmodelc` automatically.

## category model — data provenance (2026-06-20)

- Dataset: Kaggle Fashion Product Images
- URL: https://www.kaggle.com/datasets/paramaggarwal/fashion-product-images-small
- License: MIT
- Classes (26): backpack, belt, blazer, blouse, cap, dress, handbag, hat, high heel, jacket, jeans, jumpsuit, leggings, loafer, sandal, scarf, shirt, shorts, skirt, sneaker, sunglasses, sweater, sweatshirt, t-shirt, tie, trousers
- Per-class histogram:
    - shirt: 3000
    - sneaker: 3000
    - t-shirt: 3000
    - handbag: 2049
    - blouse: 1991
    - sandal: 1811
    - high heel: 1323
    - loafer: 1137
    - sunglasses: 1073
    - trousers: 1009
    - belt: 813
    - backpack: 724
    - jeans: 608
    - shorts: 547
    - dress: 464
    - sweatshirt: 285
    - cap: 283
    - sweater: 277
    - jacket: 276
    - tie: 263
    - leggings: 177
    - skirt: 128
    - scarf: 119
    - jumpsuit: 16
    - blazer: 8
    - hat: 3

#### category — accuracy (trained 2026-06-20T07:07:07Z)
- Held-out validation: 80.0%
- Held-out test: 79.0%

## category model — data provenance (2026-06-20)

- Dataset: Kaggle Fashion Product Images
- URL: https://www.kaggle.com/datasets/paramaggarwal/fashion-product-images-small
- License: MIT
- Classes (26): backpack, belt, blazer, blouse, cap, dress, handbag, hat, high heel, jacket, jeans, jumpsuit, leggings, loafer, sandal, scarf, shirt, shorts, skirt, sneaker, sunglasses, sweater, sweatshirt, t-shirt, tie, trousers
- Per-class histogram:
    - shirt: 3000
    - t-shirt: 3000
    - blouse: 1991
    - trousers: 1009
    - jeans: 608
    - shorts: 547
    - sneaker: 500
    - dress: 464
    - high heel: 400
    - loafer: 400
    - sandal: 400
    - sweatshirt: 285
    - sweater: 277
    - jacket: 276
    - leggings: 177
    - skirt: 128
    - backpack: 120
    - belt: 120
    - cap: 120
    - handbag: 120
    - sunglasses: 120
    - tie: 120
    - scarf: 119
    - jumpsuit: 16
    - blazer: 8
    - hat: 3

## category model — data provenance (2026-06-20)

- Dataset: Kaggle Fashion Product Images
- URL: https://www.kaggle.com/datasets/paramaggarwal/fashion-product-images-small
- License: MIT
- Classes (26): backpack, belt, blazer, blouse, cap, dress, handbag, hat, high heel, jacket, jeans, jumpsuit, leggings, loafer, sandal, scarf, shirt, shorts, skirt, sneaker, sunglasses, sweater, sweatshirt, t-shirt, tie, trousers
- Per-class histogram:
    - shirt: 1200
    - t-shirt: 1200
    - trousers: 1009
    - blouse: 1000
    - jeans: 608
    - shorts: 547
    - sneaker: 500
    - dress: 464
    - high heel: 400
    - loafer: 400
    - sandal: 400
    - sweatshirt: 285
    - sweater: 277
    - jacket: 276
    - leggings: 177
    - skirt: 128
    - backpack: 120
    - belt: 120
    - cap: 120
    - handbag: 120
    - sunglasses: 120
    - tie: 120
    - scarf: 119
    - jumpsuit: 16
    - blazer: 8
    - hat: 3

#### category — accuracy (trained 2026-06-20T07:25:13Z)
- Held-out validation: 75.0%
- Held-out test: 73.4%

## category model — data provenance (2026-06-20)

- Dataset: Clothing Dataset (full, high resolution)
- URL: https://www.kaggle.com/datasets/agrigorev/clothing-dataset-full
- License: CC0
- Classes (15): blazer, blouse, dress, hat, hoodie, longsleeve, outwear, polo shirt, shirt, shoe, shorts, skirt, t-shirt, tank, trousers
- Per-class histogram:
    - t-shirt: 1011
    - longsleeve: 699
    - trousers: 692
    - shoe: 431
    - shirt: 378
    - dress: 357
    - outwear: 312
    - shorts: 308
    - skirt: 155
    - polo shirt: 120
    - tank: 118
    - blazer: 109
    - hoodie: 100
    - blouse: 66
    - hat: 60

#### category — accuracy (trained 2026-06-20T07:53:28Z)
- Held-out validation: 69.5%
- Held-out test: 71.7%
