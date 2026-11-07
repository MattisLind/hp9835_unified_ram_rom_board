# HP 9835 Unified RAM/ROM Board — Revision G

This package is organized so the KiCad 9 schematic is the electrical source of truth.

## Directory layout

- `kicad/hp9835_unified_ram_rom_board/` — native KiCad 9 project.
  - `hp9835_unified_ram_rom_board.kicad_pro`
  - `hp9835_unified_ram_rom_board.kicad_sch`
  - `configuration.kicad_sch`, `usb_programming.kicad_sch`, `power_isolation.kicad_sch`, `decoupling.kicad_sch`
  - `hp9835_unified_ram_rom_board.kicad_sym`
  - `hp9835_unified_ram_rom_board.pretty/`
  - `sym-lib-table`, `fp-lib-table`
- `logic/hp9835_unified_ram_rom_board.vhd` — ATF1508 logic source.
- `tools/build_flash.py` — flash image builder.
- `documentation/` — pin plans, ROM maps, DIP-switch map and Rev-F notes.
- `requirements/` — all original design/reference material supplied for this project, including untouched source ZIP archives and the connector datasheet/photos.

## KiCad connector footprint assumptions

The custom HP 9835 card-edge footprint uses 50 contacts, 25 per side, 2.54 mm pitch, nominal 2.0 mm x 10.0 mm fingers and 1.6 mm PCB thickness. Viewed from the component side with the fingers pointing upward, the even-numbered contacts run 50 ... 2 from left to right; the solder side carries odd contacts 49 ... 1 at corresponding positions.

## Electrical basis

Revision G retains the ATF1508AS-100, MX29F400C 48-pin TSOP-I flash, CY62146ELL 44-pin TSOP-II SRAM, two 74HCT245 transceivers, configuration/base DIP switches, diagnostic header and existing memory mapping. It adds optional onboard USB programming, a ten-pin through-hole JTAG header alternative, Schottky-isolated supplies and hardware isolation of transceiver enable and MIP/. The CPLD logic and physical pad assignments are retained; two output requests now pass through external isolation logic.

The [2026-10-03 bus update](documentation/memory_bus_update_2026-10-03.md) records the original CPU signal names, resolved STM/STME contacts, connector supplies, and raw-STM clock conversion.

The [2026-10-04 configuration update](documentation/configuration_update_2026-10-04.md) describes base selection, original-circuit aliasing, the remote diagnostic switch and the deferred A/B ROM decision.

The schematic implements two order-time assembly options: FT232H USB-to-JTAG **or** a keyed 2x5, 2.54mm male through-hole JTAG header using the Atmel ATF15xx / ATDH1150USB pinout. Use the [population table](documentation/assembly_variants.csv) to select the fitted parts. Fit JP1's shunt for RUN; remove it for PROGRAM. The header assembly uses a separate regulated bench supply at J5 when outside the HP. USB is normally disconnected while the HP runs.

See the [five-sheet schematic PDF](documentation/hp9835_unified_ram_rom_board_revG.pdf) and [implementation/validation notes](documentation/programming_update_2026-11-07.md). CPLD fit/timing, USB EEPROM commissioning, Flash programming software and hardware voltage/current/backfeed checks remain to be completed.
