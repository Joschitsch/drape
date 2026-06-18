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
