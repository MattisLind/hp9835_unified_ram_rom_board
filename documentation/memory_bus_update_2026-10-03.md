# Memory-bus update — 2026-10-03

The new CPU corner schematic and Paul Berger's correspondence resolve the apparent STM conflict and the memory connector power assignments. The KiCad memory connector remains **J3**; the CPU drawing labels its connector **P2**. The separate JTAG header remains J2.

Source: [original CPU corner PDF](../requirements/original_archives/CornerOfOriginalSchematic/LowerRightCorner_CPU_2026-09-30_1155.pdf), plus Paul's messages supplied by Mattis on 2026-10-03. No generated enhancement was used as evidence.

## Original names and implementation

| Contact | CPU name | Project net | Implementation |
|---|---|---|---|
| 32 | SOB with overbar | HP_SOB_N | Replaces HP_SMC; HIGH still enables read data, following RAMMISC2.PDS |
| 33 | STME with overbar | HP_STME_N | Separately buffered strobe for ROM array/video; labelled, unused here |
| 34 | RAL with overbar | HP_RAL_N | Replaces HP_RAL; LOW denotes register access, HIGH qualifies memory |
| 38 | SUMC with overbar | HP_SUMC_N | Labelled, unused here; distinct from the card's acknowledge output |
| 40 | MIP with overbar | HP_MIP_N | Replaces HP_UMC_N; CPLD pin 35, open collector |
| 42 | STM with overbar | HP_STM_N | Raw input to CPLD GCLK1, pin 87 |
| 44 | WRT with overbar | HP_WRT_N | Existing name retained |
| 46 | phi2 | HP_PH2 | Existing ASCII clock name retained |

The reference RAM design called contact 32 SMC and contact 40 UMC. Those aliases remain only in explanatory/historical material and untouched reference archives. Original overbars are represented by `_N`; changing the name must not invert the established reference equations. SUMC on contact 38 must not be substituted for MIP on contact 40.

Pins 33 and 42 carry the same logical strobe through **different CPU buffers**. They must not be joined electrically. This card uses STM on 42 even when its ROM replacement functions are enabled. The memory cable continues to the original ROM-array board; the logical function of a ROM on this replacement card does not require using both buffered outputs.

## Power contacts

| Rail | J3 contacts | Use |
|---|---|---|
| Ground | 9, 10, 30, 31, 41, 43, 45, 47, 49 | Board GND |
| +5 V | 35, 37, 39 | Board +5V |
| +12 V | 27, 29 | Labelled common rail, no board load |
| -12 V | 28 | Labelled, no board load |
| +7 V | 50 | Labelled, no board load |

Contact 36 remains unknown and has a no-connect marker. Odd contacts are on the solder side, even contacts on the component side. J3 now has the existing custom HP card-edge footprint assigned; its assumed mechanical dimensions still need physical confirmation.

All J3 signal stubs were corrected to the physical contact numbers. Adding supplies to the previous reversed signal mapping would otherwise have left bus signals on supply contacts.

## VHDL and CPLD

The external-inverter convention is removed. The core and generated wrapper use `HP_STM_N` rather than `ALE_CLK`:

- Address, bank, BYTE, BL and WRT capture use `falling_edge(HP_STM_N)`.
- Active-cycle qualification tests `HP_STM_N = '0'` in the PH2 pipeline, MIP acknowledge, chip enables and OE/WE strobes.
- PH2 still uses its rising edge. No address-map or byte-lane behavior was changed.
- The scalar wrapper, fitter `.pin`, CSV pin plan and open-collector fitter option use the new names, including `open_collector=hp_mip_n`.

U1's previous reversed wiring was corrected to implement the established physical pin plan, including all supply and fixed JTAG pads. Pin 89 remains tied inactive. Eight spare pins are marked unconnected. Component placements and the other devices' pin connections were preserved; only the named HP nets were renamed across the sheet.

## Original RAM special mode

Paul's explanation describes address aliasing: when enabled for the relevant -BSC0 condition, modifying IDA9 maps affected addresses 512 bytes lower. It does not reserve or protect physical RAM; software manages the separate upper base page. The original DRAM design uses separate RAS decoding for its byte lanes and banks.

This project's established expansion-only policy is retained: onboard bank 000 stays onboard; expansion supplies even banks 002–016. No original-card special-mode switches or IDA9 override were added. The original card's SW1/SW2 are unrelated to this project's option DIP switch functions. Supporting the original special-mode RAM role would require a deliberate decode/memory-map change; this update does not claim that role is implemented.

## Validation

- KiCad CLI successfully parsed and exported the updated schematic.
- `python3 tools/check_memory_bus.py /tmp/hp-after.xml`: passed all 50 connector-contact checks, supply assignments, separate STM/STME and MIP/SUMC networks, and isolation of unused rails.
- `python3 tools/generate_cpld_constraints.py --check --netlist /tmp/hp-after.xml`: 71 scalar ports validated; **0 mismatches out of 92 U1 pin checks**.
- Compared all executable VHDL statements against the pre-edit source after applying the signal-name mapping and `ALE = NOT STM` substitution: exact match after removing comments/whitespace. This checks that all existing strobe qualifications were converted consistently; it is not a timing simulation.
- Compared before/after netlists: all other component pin nets are unchanged apart from the explicit HP signal renames.
- [ERC report](review_2026-10-03/erc.rpt): **4 errors, 13 warnings**. Errors are unconnected/undriven flash BYTE# and two supply-not-driven reports. Warnings include intentionally unused labelled bus contacts, SRAM library/cache mismatch and existing JTAG off-grid endpoints.

No GHDL/Yosys/fitter execution or hardware timing test was possible with the installed tools. A successful constrained fit must prove the falling-edge clock implementation, pin retention, MIP open-collector mode and EXTEST behavior.

This update does not certify the complete board for layout: the remaining ERC errors and the other-device wiring/JTAG-header findings in the historical review still need checking. In particular, fixing U1's fixed JTAG pads does not by itself reconcile the J2 header's pin names with its existing wiring.
