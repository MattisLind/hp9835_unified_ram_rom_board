# HP 9835 Unified RAM/ROM Board — Revision F

This package is organized so the KiCad 9 schematic is the electrical source of truth.

## Directory layout

- `kicad/hp9835_unified_ram_rom_board/` — native KiCad 9 project.
  - `hp9835_unified_ram_rom_board.kicad_pro`
  - `hp9835_unified_ram_rom_board.kicad_sch`
  - `hp9835_unified_ram_rom_board.kicad_sym`
  - `hp9835_unified_ram_rom_board.pretty/`
  - `sym-lib-table`, `fp-lib-table`
- `logic/hp9835_unified_ram_rom_board.vhd` — ATF1508 logic source.
- `tools/build_flash.py` — flash image builder.
- `documentation/` — pin plans, ROM maps, DIP-switch map and Rev-F notes.
- `requirements/` — all original design/reference material supplied for this project, including untouched source ZIP archives and the connector datasheet/photos.

## KiCad connector footprint assumptions

The custom HP 9835 card-edge footprint uses 50 contacts, 25 per side, 2.54 mm pitch, nominal 2.0 mm x 10.0 mm fingers and 1.6 mm PCB thickness. Viewed from the component side with the fingers pointing upward, the even-numbered contacts run 50 ... 2 from left to right; the solder side carries odd contacts 49 ... 1 at corresponding positions.

## Revision F electrical basis

Revision F carries forward the Rev-E architecture: ATF1508AS-100, MX29F400C 48-pin TSOP-I flash, CY62146ELL 44-pin TSOP-II SRAM, two 74HCT245 transceivers, a 12-pole configuration DIP, a four-pole RAM-base DIP and a remote diagnostic header, 15-bit HP word address plus seven bank-select signals, shared MEM_OE#/MEM_WE#, direct open-collector MIP/ (CPU schematic name; reference RAM design calls it UMC), and base-relative 512 KiB SRAM mapping with diagnostic scratch sharing the first 256 words.

The [2026-10-03 bus update](documentation/memory_bus_update_2026-10-03.md) records the original CPU signal names, resolved STM/STME contacts, connector supplies, and raw-STM clock conversion.

The [2026-10-04 configuration update](documentation/configuration_update_2026-10-04.md) describes base selection, original-circuit aliasing, the remote diagnostic switch and the deferred A/B ROM decision.
