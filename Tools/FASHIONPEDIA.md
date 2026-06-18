# Fashionpedia — attribute ground truth (DEBUG harness only)

Used to **measure** Drape's visually-derivable attribute autofill (pattern, bottom
volume, top length, best-effort texture) — never to train a shipped model.

## Licensing
- **Annotations + ontology: CC BY 4.0** (commercial use OK, attribution required).
  These are what we score against. Attribution: *Fashionpedia (Jia et al., ECCV
  2020), https://fashionpedia.github.io* — annotations CC BY 4.0.
- **Images: mixed per-source** (Flickr/Unsplash/Pexels/Burst/…), and the dataset
  does **not** expose per-image license. So images are used **locally for
  measurement only** — gitignored, never committed, never shipped, never used to
  train a shipped model. Same local-only handling as `clothing-dataset-small`.

## Get the data (local, not committed) — simplest path
On a Mac (val split is small, ~1k images — train is multi-GB, not needed):

    mkdir -p ~/fashionpedia && cd ~/fashionpedia
    curl -L -O https://s3.amazonaws.com/ifashionist-dataset/annotations/instances_attributes_val2020.json
    curl -L -O https://s3.amazonaws.com/ifashionist-dataset/images/val_test2020.zip
    unzip -q val_test2020.zip            # images land in ./test (val+test together)

Arrange as a single folder (the picker auto-finds the .json and the images subfolder):

    fashionpedia/
      instances_attributes_val2020.json
      val/   (or test/ — any images subfolder works)

Drop `fashionpedia/` into **iCloud Drive**. Then on the device:
Profile → Developer → Test harness → **Choose Fashionpedia folder…** → pick it.
(No copying into the app's Documents, no exact paths. The "explicit paths"
disclosure is a fallback, handy on the Simulator.)

## How it's used
`FashionpediaCocoSource` parses the JSON, and for each garment *annotation* crops
its bbox and maps its CC-BY attributes to ground truth via
`FashionpediaAttributeMap` (textile pattern → PatternType, silhouette →
BottomVolume, length → TopLength, finishing/material → texture best-effort).
Parts (sleeve, collar, …) don't map to a `GarmentCategory` and are skipped.
Runs on device only (the model/Vision path needs a real device).
