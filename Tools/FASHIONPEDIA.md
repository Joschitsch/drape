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

## Get the data (local, not committed)
Download the Fashionpedia images + COCO `instances_attributes` JSON from
https://github.com/cvdfoundation/fashionpedia (val split is plenty for the
harness). Drop into the app's Documents, e.g.:

    <app Documents>/fashionpedia/
      instances_attributes_val2020.json
      val/<images>.jpg

Then in-app: Profile → Developer → Test harness → **Import Fashionpedia (COCO)**.

## How it's used
`FashionpediaCocoSource` parses the JSON, and for each garment *annotation* crops
its bbox and maps its CC-BY attributes to ground truth via
`FashionpediaAttributeMap` (textile pattern → PatternType, silhouette →
BottomVolume, length → TopLength, finishing/material → texture best-effort).
Parts (sleeve, collar, …) don't map to a `GarmentCategory` and are skipped.
Runs on device only (the model/Vision path needs a real device).
