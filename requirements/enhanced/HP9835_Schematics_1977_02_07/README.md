# HP 9835 memory connector: enhanced original scan

Source: `requirements/original_archives/HP9835_Schematics_1977_02_07.pdf`, page 1, right-hand signal column. The drawing uses **P2**; this is the connector referred to as J2 in the request. The mating connector designation is not established by this crop alone.

## Images

- [Bus pins, moderate contrast](bus_red_moderate.png)
- [Control pins, moderate contrast](controls_red_moderate.png)
- [Control pins, stronger contrast](controls_red_strong.png)
- [Control circuitry and traces](controls_tracing_red_moderate.png)
- [Complete connector column](connector_column_red_moderate.png)
- [Complete first page](page1_red_moderate.png)
- [Original embedded JPEG](page1_embedded_original.jpg)
- [Transcription with confidence](connector_transcription.csv)

## What can be extracted

The bus column supports the existing reference-card mapping:

| P2 contacts | Signals in ascending signal order |
|---|---|
| 1–7 | BSC0–BSC6 |
| 11, 13, 15, 17, 19, 21, 23, 25 | IDA0–IDA7 |
| 12, 14, 16, 18, 20, 22, 24, 26 | IDA8–IDA15 |

Signal names here are normalized; overbars/polarity markings are not reliably recoverable throughout this scan. Existing project `_N` names come from the earlier reference review, not a fresh polarity determination from this image.

The control-column contact numbers appear, from top to bottom below IDA15, to be **48, 8, 44, 34, 46, 32, 42, 40**. Several are damaged. Their expected signal names, from the separate RAM/ROM card references, are BYTE, BL, WRT, RAL, PH2, SMC, STM and UMC respectively. These names must not be mistaken for independently legible transcriptions of the faint lettering here.

The apparent **42** is consistent with the RAM card's RAMALE connection. However, the corresponding signal lettering is too degraded to independently establish STM from this crop. This remains supporting evidence, not a sufficient resolution of the ROM drawing's pin 33 versus RAM drawing's pin 42 discrepancy. No schematic or authoritative project pin assignment was changed.

The lower-right entries are too damaged for dependable additional pin/signal pairs. In particular, this enhancement does **not** establish the power/ground contacts, unused contacts, or WAIT on pin 38. Absence from the transcription does not mean a contact is unconnected.

## Method and limitations

The original page contains a 2872 × 1712 JPEG. Its compressed bytes were extracted directly from the first image stream; the original JPEG is retained. Enhancement decodes that image and applies only pointwise levels to the red channel:

`output = clamp((red - blackPoint) * 255 / (255 - blackPoint), 0, 255)`

Black points are 190 (moderate), 225 (strong) and 240 (extreme). Crops retain native pixel resolution. There is no generative reconstruction, sharpening, inpainting, or replacement lettering. Higher contrast can obscure remaining strokes, so compare the moderate and original images when interpreting characters. Clipping is irreversible in the enhanced outputs; the original is preserved separately.

Reproduce PNGs from the project root:

```sh
swift -module-cache-path /tmp/hp9835-swift-cache tools/enhance_hp9835_scan.swift
```

The earlier file `page1_controls_AI_viewing_only.png` is an AI-generated experiment and is explicitly excluded from all transcription evidence. Use the deterministic images linked above.

Original embedded JPEG SHA-256: `b82963e5c89e78f2268027d4d6a251cbc269033456d56a6928a1f75c43aae4df`.

## Later evidence

The new CPU corner schematic and Paul Berger correspondence supplied on 2026-10-03 resolve the STM and supply questions above. See `documentation/memory_bus_update_2026-10-03.md`. This enhancement report remains a record of what could be read from the older scan.
