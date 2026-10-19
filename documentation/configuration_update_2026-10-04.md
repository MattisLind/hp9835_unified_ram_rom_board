# Configuration update — 2026-10-04

Implemented the requested four-pole RAM-base DIP and external diagnostic header. Retained the 12-pole configuration DIP. The 9835A/9835B ROM distinction is deferred at Mattis's explicit request until he checks the differing ROMs and their addresses.

## Controls

| Component | Function |
|---|---|
| SW2 poles 1–9 | Existing individual option-ROM enables |
| SW2 pole 10 | Reserved for possible A/B selection; **currently no effect** |
| SW2 pole 11 | RAM enable, ON enables the full 512 KiB |
| SW2 pole 12 | System-ROM replacement enable, existing decode retained |
| SW3 poles 1–4 | RAM base bits 0–3; ON=1, each count is 64 KiB |
| J4 pins 1–2 | External diagnostic switch; short=enabled, open=normal |

SW2's previously reversed pole/net order was corrected: pole 1 (pad 1) is DIP_N0, through pole 12 (pad 12) as DIP_N11. This changes the physical switch order from the earlier schematic to match the documented functions.

SW3 is `Switch:SW_DIP_x04`. SW2 and SW3 have matching generic low-profile SMD DIP footprints with 2.54 mm pitch and 8.61 mm pad-row spacing. Verify these dimensions against the switches actually purchased. J4 is a standard vertical 1×2, 2.54 mm header suitable for a jumper or wires to a remote dry-contact switch. R19–R23 are 10k, `R_Small`, SMD 0805 pull-ups.

J4.1 is DIAG_N and J4.2 is ground. Select diagnostic mode before reset/boot. There is no debounce or runtime mode-transition protocol; moving a mechanical switch during an active memory cycle is not a supported timing operation.

## RAM base and extent

Mattis confirmed **64 KiB steps and the full 512 KiB**. Let B be the logical four-bit base value. Ordinary RAM occupies the eight even HP blocks `2B` through `2(B+7)`. Physical SRAM bank equals `HP block/2 − B`; the low 15 word-address bits pass through unchanged.

| Base | SW3 poles 4..1 | RAM start | HP blocks (octal, even only) |
|---|---|---|---|
| 0 | OFF OFF OFF OFF | 0 KiB | 000–016, plus block 001 special alias |
| 1 | OFF OFF OFF ON | 64 KiB | 002–020 |
| 8 | ON OFF OFF OFF | 512 KiB | 020–036 |
| 15 | ON ON ON ON | 960 KiB | 036–054 |

The upper base settings do not wrap. Base 15 ends at 1472 KiB exclusive. Any existing RAM responding within the selected window must be removed or disabled; base zero now replaces the original base RAM rather than avoiding block 000.

## Special alias at base zero

Source: [Paul's original RAM schematic, page 1](../requirements/original_archives/HandDrawnSchematicRAMCard/9835_64K_RAMCard_Schematic.pdf), U13 and the special-mode switches. Mattis explicitly selected **follow the original gate circuit** when asked about the correspondence's ambiguous polarity/byte-offset wording.

The circuit gates the active-low IDA9 line with active-low BSC0. For special block 001, BSC0 is LOW, so the physical IDA9 value into RAM is forced LOW. The CPLD has already complemented IDA into a positive logical address; therefore its SRAM address bit 9 is forced **HIGH** in this mode. This aliases address pairs separated by 512 **words**, or 1024 bytes. For example block 001 word 0x0000 and word 0x0200 both map to physical word 0x0200, which is also visible in ordinary block 000.

Only block 001 gets this behavior, only at base zero and with RAM enabled. Other odd blocks remain available to ROM. No region is protected or removed from the 512 KiB physical RAM.

## Diagnostic scratch shares normal RAM

Diagnostics are now controlled only by J4, independently of SW2 RAM enable. Diagnostic ROM stays in block 045 segment 0. Its scratch RAM remains at the top 256 words of block 045, translated to physical SRAM words 0x00000–0x000FF.

Since the whole SRAM is now exposed, those words **also belong to the first configured ordinary RAM bank**. Diagnostic writes can overwrite them. This explicit alias keeps the full 512 KiB available; there is no hidden reservation or separate scratch storage.

## A/B ROM work deferred

No different A/B decode was invented. SW2 pole 10 is wired and reserved, but ignored by the current RTL. The flash layout and builder remain unchanged. The existing LPU block 003 and PPU block 005 decode is retained pending verification; this update does not certify two system-ROM variants.

Mattis recalls that the differing ROMs may occupy non-overlapping regions, so both may be mapped simultaneously without using a selector. Confirm part numbers, image contents, blocks and segments first. As a cross-check, the [MAME driver](https://github.com/mamedev/mame/blob/master/src/mame/hp/hp9845.cpp) currently aliases the 9835B ROM definition to 9835A, so it does not resolve the hardware distinction raised here.

## CPLD assignments and validation

Added BASE_N0–3 at pins 46, 47, 96, 97, and DIAG_N at pin 98. Three spare pads remain: 85, 99, 100. Existing fixed clocks, JTAG and supply assignments remain intact. Generated wrapper and fitter pin file now cover 76 scalar functional ports.

- GHDL analysis, elaboration and simulation passed: 49,152 RAM mapping cases, diagnostic boundary/enable checks, RAL exclusion, RAM disable and write sequencing.
- GHDL generic synthesis of the core plus scalar wrapper to Verilog passed. ATF1508 technology mapping, resource fit and timing are still unverified.
- Exported KiCad netlist passed all 50 connector checks, all 97 required U1 pin checks, and switch/header/pull-up checks.
- New configuration area was visually inspected through a KiCad PDF export; label and value overlaps were corrected.
- ERC remains at the previous **4 errors and 13 warnings**; the added circuitry introduces no additional reported violations. See [report](review_2026-10-04/erc.rpt). Flash BYTE# and power-driver declarations remain unresolved, along with previously documented review items.

Run instructions are in [tests/README.md](../tests/README.md). A successful constrained ATF1508 fit and remaining schematic review are still required before layout is frozen.
