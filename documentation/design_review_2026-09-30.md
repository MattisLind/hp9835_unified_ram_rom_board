# Revision F design review — 2026-09-30

> Historical review. The [2026-10-03 update](memory_bus_update_2026-10-03.md) supersedes the STM conflict, supply mapping, CPU signal naming and U1 wiring findings below. Other findings still require review.

**Disposition: do not proceed to PCB layout from this schematic.** The intended architecture is plausible, but the actual schematic connectivity has widespread faults, including reversed supply connections. This review leaves the schematic, symbols, HDL and design decisions unchanged.

## Scope and evidence

Reviewed design_decisions.md, all supporting CSVs, fitter notes, VHDL, image builder, custom symbols/edge footprint, reference PAL equations, the three reference explanatory PDFs, and reference schematics (including visual inspection of the scanned RAM and diagnostic diagrams). Ran ERC and exported a KiCad XML netlist using the installed **KiCad CLI 10.0.5** on the KiCad 9-format source. This is not a KiCad 9 GUI compatibility sign-off.

Evidence is saved in [review_2026-09-30](review_2026-09-30/): `erc.rpt`, `actual_pin_nets.csv`, and `pin_plan_mismatches.csv`. Net names below omit KiCad's leading `/` sheet prefix.

ERC: **44 errors, 383 warnings**. Breakdown: 23 unconnected pins, 19 undriven power pins, 2 undriven inputs; 371 off-grid endpoints, 5 ground-pin warnings, 4 connected no-connect markers, 3 unconnected wire endpoints. These are not all independent design defects, and correcting ERC alone will not detect every incorrect pin assignment.

No CPLD synthesis/fitting, HDL simulation, hardware measurements, complete manufacturer pin-by-pin sign-off, or live JTAG programming was performed. No HDL simulator was found on PATH. Manufacturer documentation was consulted for memory electrical characteristics and CPLD open-drain/boundary-scan capabilities; this does not establish that this particular implementation works.

## 1. Critical: symbol-to-sheet coordinate conversion has scrambled connectivity

The pattern strongly indicates that wiring was generated with the wrong sign for symbol-local Y coordinates. For unrotated symbols, a positive library Y coordinate projects upward on the sheet, not downward. For example, U1 is placed at (102,145), and library pin 1 is at (-20.32,+62.23), so its sheet position is (81.68,82.77). The exported netlist connects that pin to FLASH_RYBY_N rather than MEM_D0.

All **76 documented non-spare U1 functional assignments** differ from `pin_plan.csv`; **29 of 31 documented J1 signal assignments** differ from `hp9835_connector_pinmap.csv`. Correct the coordinate conversion or reconnect using KiCad, then compare a fresh exported netlist against an independently verified pin table. Do not change the pin tables to bless the corrupted netlist.

Examples from the actual netlist:

| Device/pin | Actual connection | Required/intended connection |
| --- | --- | --- |
| U2/U3 pin 10 (GND) | +5V | GND |
| U2/U3 pin 20 (VCC) | GND | +5V |
| U6 pin 7 (GND) | +5V | GND |
| U6 pin 14 (VCC) | GND | +5V |
| U5 pins 11/33 (VCC) | GND | +5V |
| U5 pins 12/34 (VSS) | +5V | GND |
| U4 pin 37 (VCC), 27/46 (GND) | Unconnected | +5V, GND |
| U1 pin 11 (GND) | FLASH_CE_N | GND |
| U1 pin 26 (GND) | HP_BSC_N3 | GND |
| U1 pin 35 | MEM_D11 | HP_UMC_N |
| U1 pin 87 (GCLK1) | MEM_A1 | ALE_CLK |
| U1 pin 90 (GCLK2) | DIP_N8 | HP_PH2 |
| U1 JTAG pins 4/15/62/73 | Unconnected / XCVR_OE_N / +5V / MEM_A12 | TDI / TMS / TCK / TDO |
| U2/U3 pin 1 (DIR) | XCVR_OE_N | XCVR_DIR |
| U2/U3 pin 19 (OE#) | XCVR_DIR | XCVR_OE_N |
| U5 pin 17 (WE#) | Unconnected | MEM_WE_N |
| U4 pin 47 (BYTE#) | MEM_A14 | +5V for x16 mode |
| J1 pin 1 | Unconnected | HP_BSC_N0 |
| J1 pin 49 | HP_BSC_N0 | Unresolved in pin map |
| J1 pin 40 | HP_IDA_N8 | HP_UMC_N |

JTAG header wiring also disagrees with its symbol labels: symbol pin 1 is TCK but wired +5V; symbol pin 5 is +5V but wired TCK. SW1 physical switch ordering is reversed: DIP_N0 goes to pin 12 (labelled SW12), and DIP_N11 to pin 1 (SW1).

The fault affects much more than these examples. Recheck every supply, address, data, control and connector pin after repair. Incorrect power wiring could damage a populated board if powered.

## 2. High: connector definition is incomplete and references conflict

Neither +5V nor GND has any J1 node in the exported netlist. The existing documentation correctly flags unresolved supply contacts, but the schematic is therefore not yet a complete card powered from the HP backplane. Verify supply contacts and all return paths on an original card/backplane before assigning them. Do not add power flags merely to hide missing supply wiring.

There is also a specific unresolved source disagreement: `RAM_Schematic.pdf` labels **RAMALE (42)** at the timing PLD, whereas `9835_ROM_Diagram.pdf` labels **ALE_IN 33**. The current CSV chooses pin 33 and calls it verified without noting this conflict. Confirm STM at the connector from original HP documentation or measurement; one reference may contain a drafting error. The current generated schematic actually connects HP_STM_N to J1 pin 17, which is a separate coordinate fault.

`RAM_Card.pdf`, page 2, additionally identifies pin 38 as active-low WAIT inhibiting UMC. The CSV calls it unresolved. Record that source as reference evidence; do not drive it without verifying its electrical behavior. The diagnostic card uses a different, front ROM-slot connector and is not a source for the 50-contact memory connector numbering.

## 3. High: shared address/data capture timing needs validation

See VHDL `XCVR_DIR`, `XCVR_OE_N`, and PH2 sequencing (approximately lines 347–406). The original RAM board latches addresses directly from HP IDA, independently of its data transceivers. Revision F captures through the transceivers, adding both propagation delay and a new direction-turnaround dependency.

The current direction and transceiver-enable equations are not qualified by ALE_CLK. After a selected read, when ALE_CLK falls, phase1 remains high until a PH2 edge. During that interval XCVR_DIR remains MEM-to-HP; with SMC low the transceiver is disabled. The comment promising HP-to-MEM throughout idle/address preparation is therefore not universally true. If the next address-latch edge occurs before a PH2 reset, the new address cannot reach MEM_D. This is a concrete RTL state sequence; whether the real HP bus permits it needs a timing trace.

Validate minimum STM inactive time, PH2 phase, address setup/hold through HCT245 plus CPLD input setup, and read-to-read/read-to-write/unselected-cycle transitions. Also check memory output-disable versus transceiver reversal and ensure OE/direction propagation skew cannot briefly enable two opposing drivers. Combinational changes to OE and DIR at the same PH2 event do not by themselves guarantee break-before-make.

RAL is used live in this HDL; the reference ROMSEL registers the selected result including RAL. WRT is newly latched in this HDL whereas RAMMISC2 uses the live signal. Check both choices against measured bus timing. These are validation items, not evidence that the whole architecture must be abandoned.

## 4. High: CPLD fit and programming implementation are missing

`pin_plan.csv` and `ATF1508_fitter_requirements.txt` are documentation, not executable pin/fitter constraints. There is no fitted implementation or timing/resource report in the repository. Fit the exact ATF1508AS package and speed grade before freezing the PCB pinout, preserving all boundary-scan signals even if synthesis considers them unused.

The intended open-drain UMC approach is supported by the [ATF1508AS datasheet, page 7](https://ww1.microchip.com/downloads/en/DeviceDoc/ATF1508AS%28L%29-5V-128-Macrocell-CPLD-Data-Sheet-20006682A.pdf). But the VHDL itself outputs 0/1 and relies on a fitter option to make 1 release the line. Verify the actual fitted setting, keeper behavior, power-up behavior, and JTAG behavior. Disable both PD1 and PD2 alternate functions because the proposed pin plan uses both pins for ordinary bus signals.

JTAG flash programming is currently an architectural intention: there is no BSDL-based programmer, command sequence, or demonstrated EXTEST drive/capture implementation. Distinguish **complemented ROM payload words** from **flash command words**. The latter must be the command values required at the flash pins, not blindly complemented CPU-visible values. Specify output file byte order for the chosen programmer. Verify safe boundary-scan preload, SRAM deselection, transceiver isolation, and entry/exit behavior. Programming while installed also requires that UMC remain released, not just that the data transceivers be isolated.

The [Macronix datasheet](https://www.macronix.com/Lists/Datasheet/Attachments/8538/MX29F400C%20T-B%2C%205V%2C%204Mb%2C%20v2.3.pdf) defines the command sequences and RY/BY# behavior. Provide a defined pull-up on the open-drain RY/BY# status line if it is used; none appears in the netlist. MEM_OE_N also lacks the external inactive-state pull-up present on CE#/WE#; document how its required idle state is guaranteed while the CPLD is unprogrammed or being reprogrammed.

## 5. Medium: finish schematic/PCB preparation after electrical repair

U2, U3, U6 and SW1 have no footprint assigned. Choose actual orderable packages and verify all symbol pad numbers against them. The 371 off-grid warnings indicate systematic placement outside the configured connection grid; normalize placement/wiring together and re-export rather than moving isolated endpoints.

The custom connector footprint agrees with the documented orientation (front even numbers 50 to 2 left-to-right, matching rear odd numbers) and 2.54 mm pitch. It has copper/mask fingers without paste. Finger dimensions, board thickness, insertion depth, mounting outline and bevel remain physical measurements to obtain; its drawing line is not an Edge.Cuts board outline. The footprint excludes J1 from BOM/position outputs, which is reasonable for integral edge fingers.

Plan local bypassing for every CPLD supply group and each other IC, plus suitable bulk capacitance and a backplane power budget. Eight anonymous 100 nF capacitors alone do not establish placement or transient-current adequacy.

## 6. Medium: image builder silently overwrites duplicate placements

A temporary smoke test passed the 524288-byte output size, diagnostic offset 0x60000, and complemented big-endian conversion (`1234 ABCD` becomes `EDCB 5432`). The supplied DIAG.rom is 8192 bytes, matching one segment. Its actual word byte order still needs confirmation using known instructions/words or a verified dump convention.

A second manifest entry for the same bank/segment is accepted silently and overwrites the previous data; a shorter second file leaves a mixed image. Reproduced with `1234 ABCD`, then `5678`, yielding `A987 5432`. Reject overlaps/duplicate placements and report missing or unexpectedly short required ROMs before treating output as programming-ready. Input paths currently resolve relative to the shell working directory, not the manifest directory; document or change that behavior.

## Decisions that check out at the architectural level

- The supplied RAM notes explicitly establish a 15-bit word address, 16-bit multiplexed active-low bus, and seven active-low bank bits.
- Seven 32K-word expansion banks plus the onboard 32K-word RAM yield 512 KiB total. Mapping octal 002–016 even banks to physical SRAM banks 1–7 leaves bank 0 free. The original RAM card also supplied bank 020; omitting it here is the intentional capacity choice, not an octal error.
- Diagnostic ROM at bank 045 segment 0 and scratch RAM at the top 256 words agree with the diagnostic description. Mapping scratch RAM into physical SRAM 0x00000–0x000FF avoids expansion-bank aliasing.
- The reference BLKSEL3 byte-write equations agree with the intended BLE/BHE HDL lane selection. Latching BYTE/BL is supported by the author's reported fix.
- Complementing ROM payloads is consistent with changing from the reference inverting ROM buffers to non-inverting 245s. SRAM data can round-trip in physical complemented representation.
- Shared OE#/WE# with mutually exclusive chip enables is a viable architecture; the actual faulty netlist does not implement it yet.
- Mass-storage, programming and basic-datacomm selections represented in ROMSEL agree with the corresponding new decode. The full I/O/plotter/system-ROM maps and complete Bisync coverage are not independently established by those PAL sources; retain a primary ROM-map reference or verified dumps for final sign-off.
- The selected [CY62146ELL](https://www.infineon.com/part/CY62146ELL-45ZSXI) is a 5 V, 256K × 16 SRAM, consistent with the capacity/voltage plan.

## Recommended order before layout

1. Repair symbol-to-sheet wiring and reconcile every exported pin/net with verified pin tables, including all power pins and JTAG.
2. Resolve STM connector numbering and establish supply contacts/mechanics from authoritative evidence or measurement.
3. Complete package assignments, supply/bypass details, and intentional no-connects; rerun ERC and inspect in KiCad 9.
4. Obtain a successful constrained CPLD fit and timing report, then simulate/measure bus capture and turnaround cases.
5. Freeze the corrected schematic and pinout before routing; validate the ROM image/programming path before powering a populated card in the HP.

Documentation housekeeping: README files claim untouched ZIP archives are present, but `original_archives/` currently contains unpacked directories, not those ZIP files. Fitter notes still say Rev E; image-builder comments say Rev C. Update these descriptions when the design is corrected, and replace the schematic's unconditional “pinouts verified” statement with the actual verification status.
