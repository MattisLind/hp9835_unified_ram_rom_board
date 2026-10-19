# Memory connector and CPLD pin review

> Historical review. The [2026-10-03 update](memory_bus_update_2026-10-03.md) supersedes the STM conflict, supply mapping, CPU signal naming and U1 wiring findings below. Other findings still require review.

Review of the current saved schematic on 2026-09-30. The memory connector is now **J3**, a `Connector_Generic:Conn_02x25_Odd_Even`; older documentation calls it J1. The diagnostic/front-ROM-slot card was excluded from the connector comparison.

**Result:** the connector and CPLD wiring do not implement the reference pinout or intended pin plan. The ATF1508 custom symbol's physical pin names/numbers are correct; its attached nets are not. The generated constraints describe the intended corrected circuit, not the current netlist. Schematic wiring and core RTL were left unchanged in this review.

## Memory connector

Sources inspected: `requirements/extracted/RAM_Card/RAM_Schematic.pdf`, `requirements/extracted/9835_ROMCard/9835_ROM_Diagram.pdf`, and explanatory `RAM_Card.pdf`. See [the full 50-contact comparison](pin_audit/connector_comparison.csv).

| Contact(s) | Reference function |
| --- | --- |
| 1–7 | BSC0#–BSC6# |
| 8 | BL# (RAM drawing) |
| 11,13,15,17,19,21,23,25 | IDA0#–IDA7# |
| 12,14,16,18,20,22,24,26 | IDA8#–IDA15# |
| 32 | SMC |
| 34 | RAL |
| 40 | UMC# |
| 44 | WRT# (RAM drawing) |
| 46 | PH2_TTL |
| 48 | BYTE# (RAM drawing) |
| **33 or 42** | **Unresolved STM conflict:** ROM drawing says ALE_IN (33); RAM drawing says RAMALE (42) |

Of the 30 signal contacts not involved in the STM conflict, only J3.25 and J3.26 currently match. Examples: BSC0# is on 49 instead of 1; IDA0# on 39 instead of 11; UMC# on 12 instead of 40; PH2 on 6 instead of 46. This is consistent with the previous symbol-to-sheet Y-coordinate error. A correct odd/even connector symbol does not fix reversed labels/wires.

The drawings do not establish power/ground contact numbers. The current netlist has no +5V/GND connections to J3. `RAM_Card.pdf` page 2 identifies contact 38 as active-low WAIT, inhibiting UMC; this is documentary evidence, not a verified hardware measurement. Updated the existing connector CSV to expose the STM disagreement and WAIT evidence without inventing supply assignments.

J3 also has **no footprint assigned**. Once its contact mapping is verified, use the project's male card-edge footprint, not a generic two-row header. Its front/back orientation is independent of the schematic symbol's display order. Verify against an original HP card before manufacturing.

## CPLD physical pinout and JTAG

Checked all 100 pin names/numbers in both the library and schematic's embedded ATF1508 symbol against the manufacturer TQFP100 pinout. They agree. This package must not be confused with the 100-pin PQFP, whose assignments differ. Source: [ATF1508AS datasheet, pages 4–5](https://ww1.microchip.com/downloads/en/DeviceDoc/ATF1508AS%28L%29-5V-128-Macrocell-CPLD-Data-Sheet-20006682A.pdf).

| Signal | Required TQFP100 pin | Current net location |
| --- | --- | --- |
| TDI | 4 | 47 |
| TMS | 15 | 36 |
| TCK | 62 | 89 |
| TDO | 73 | 78 |
| ALE_CLK / GCLK1 | 87 | No ALE_CLK net; raw HP_STM_N is on 64 |
| HP_PH2 / GCLK2 | 90 | 61 |
| HP_RAL | 88 (planned dedicated input) | 63 |
| HP_UMC_N | 35 (planned I/O) | 16 |

The dedicated JTAG pad positions cannot be changed by VHDL or pin constraints. Pin 62 currently has +5V attached and pin 4 is unconnected. JTAG is consequently not wired to a usable hardware TAP.

Supplies are fixed too: VCCINT 39/91; VCCIO 3/18/34/51/66/82; GND 11/26/38/43/59/74/86/95. Examples of present faults include FLASH_CE_N on ground pin 11 and MEM_D8 on VCCINT pin 39.

[The full 100-pin comparison](pin_audit/cpld_comparison.csv) separates physical silicon functions, planned nets, and actual nets. **All 92 checked pins differ**: 71 core-port bits, four JTAG pads, 16 supply pads and the pin-89 inactive tie. Eight other pads are proposed spares; they are shown but not counted as required nets.

J2's cached symbol labels also conflict with its attached nets. As currently wired its contacts are 1=+5V, 2=GND, 3=TMS, 4=TDI, 5=TCK, 6=TDO. Its symbol pin names instead say 1=TCK, 2=TDO, 3=TMS, 4=TDI, 5=+5V, 6=GND. Choose the intended programmer cable pinout, then make names and wiring agree. Do not assume this is a standard six-pin cable.

## Relationship to VHDL

The core describes behavior and logical ports; it previously contained no physical pin assignments. The old CSV was only a plan. Its 71 functional port-bit assignments cover the VHDL completely and legally, using 68 ordinary I/O pads and three dedicated inputs. Hardware JTAG is not a core VHDL port. GCLR and spare pads are also not core ports.

A separate functional mismatch needs attention: the latest schematic has removed the external inverter and uses raw HP_STM_N. The RTL still captures on the rising edge of **inverted** STM (`ALE_CLK`) and uses that polarity throughout its timing logic. Restore the intended inverter and ALE_CLK connection, or deliberately revise the RTL/constraints for raw STM with an equivalent clock and gating polarity. Merely renaming HP_STM_N to ALE_CLK is incorrect.

The source also leaves MEM_D15 and FLASH_RYBY_N unused in normal logic and drives FLASH_RESET_N constantly high. Their fitted behavior and EXTEST access must be verified; logical port presence alone does not prove a working flash programmer.

## Pin files and routing

Added:

- `logic/constraints/hp9835_unified_ram_rom_board_pinned.pin`: actual FIT1508 pin-file syntax, assigning 71 scalar names.
- `logic/hp9835_unified_ram_rom_board_pinned.vhd`: generated scalar-port wrapper with explicit associations to the existing core; no logic changes.
- `logic/synth_atf1508.tcl`: GHDL/Yosys adapter for the upstream ATF15xx mapping flow.
- `tools/generate_cpld_constraints.py`: regenerates/validates the files and optionally checks a KiCad XML netlist.
- `logic/constraints/README.md`: tool setup, synthesis/fitter invocation and verification requirements.

The `.pin` is consumed by **Microchip FIT1508 after synthesis**, not directly by Yosys. The fitter must use `-preassign KEEP` so a difficult fit cannot silently change PCB connections. The upstream script normally extracts `.pin` from Verilog comments, so the supplied instructions bypass that overwrite behavior. Sources: [upstream ATF15xx flow](https://github.com/hoglet67/atf15xx_yosys) and [Microchip fitter guide](https://ww1.microchip.com/downloads/aemDocuments/documents/MPD/ProductDocuments/UserGuides/ATF15XX-ATF1500-CPLD-Fitter-User-Guide-DS20007127.pdf).

Retained the original legal allocation as a routing starting point rather than adopting the corrupted schematic:

| Physical pad region | Planned function |
| --- | --- |
| 1–21, skipping fixed supplies/JTAG | MEM_D0–15, largely along one package edge |
| 22–33, skipping fixed supply pads | HP bank and cycle-control inputs |
| 35–50, skipping fixed supply pads/spares | Memory controls, transceiver controls, UMC and flash status |
| 52–61 plus 92–94 | Configuration switches |
| 63–84, skipping fixed supplies/JTAG | MEM_A0–17, on the opposite side from most data pins |
| 87/90 | Address-latch and PH2 clocks |

This arrangement leaves a sensible starting placement with the CPLD between the transceiver data bus and the memory address bus. It is not a routing optimization or a proven fit. Configure package rotation and place memories/transceivers first; then adjust ordinary GPIO assignments if routing or fitter resource constraints justify it. JTAG and supply pads stay fixed, and clocks should retain appropriate clock-capable pins. Update the CSV, generated constraints, and schematic together.

## Validation and remaining work

Static checks pass for complete port coverage, directions, pin uniqueness and reserved-pin legality. Both CPLD symbol copies match the manufacturer pin functions. Exported the latest schematic using KiCad CLI 10.0.5 and compared its actual nets, rather than trusting displayed labels.

No Yosys, GHDL or Wine executable is on PATH, so there is **no synthesis, successful fit, timing report or JEDEC validation** yet. The supplied flow is an integration starting point, not proof that the design fits. Select the exact purchased part/speed grade before fitting. Repair the schematic and resolve STM/supply contacts before layout; then require a successful constrained fit and timing review before freezing the routing.
