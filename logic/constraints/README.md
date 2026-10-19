# ATF1508AS TQFP100 pin constraints

These files implement `documentation/pin_plan.csv`. U1 now matches all 97 checked assignments in the 2026-10-04 KiCad netlist. See `documentation/memory_bus_update_2026-10-03.md` for remaining board checks.

`hp9835_unified_ram_rom_board_pinned.pin` is a Microchip **FIT1508** input, used after Yosys synthesis. It is not an FPGA PCF/XDC file or a direct Yosys placement command. It assigns all 76 scalar core-port bits, reserving the four hardware JTAG pins. Supply pins, GCLR tie-off, and spare pads are board connections, not VHDL ports.

The generated `../hp9835_unified_ram_rom_board_pinned.vhd` wrapper associates every scalar pin name explicitly with a core port/bit. The lowercase names in the `.pin` file match this wrapper. This avoids vector-bit order and case ambiguities between VHDL, GHDL, EDIF and the fitter. The wrapper adds no logic. The core now samples raw STM/ on its falling edge.

## Generate and check

From the repository root:

```sh
python3 tools/generate_cpld_constraints.py
python3 tools/generate_cpld_constraints.py --check
```

To also check an exported **KiCad XML** netlist:

```sh
python3 tools/generate_cpld_constraints.py --check --netlist /path/to/schematic.xml
```

A wiring mismatch returns a nonzero exit code. Editing the CSV regenerates both files. The generator checks port coverage/directions, uniqueness, reserved supplies/JTAG pins, dedicated-input restrictions and planned clock pins.

## Synthesize and fit

Dependencies: Yosys with the GHDL plugin, a GHDL backend supporting synthesis, the [atf15xx_yosys](https://github.com/hoglet67/atf15xx_yosys) mapping files, and licensed/installed Microchip fitter files `fit1508.exe`, `aprim.lib`, and `atmel.std`. GHDL 6.0.0 was used from a temporary standalone installation for configuration simulation. GHDL also elaborated the complete scalar wrapper and synthesized it to generic Verilog. Yosys technology mapping and FIT1508 have not been run; **target fitting and timing remain unverified**.

```sh
export ATF15XX_YOSYS_DIR=/absolute/path/to/atf15xx_yosys
yosys -m ghdl -c logic/synth_atf1508.tcl
```

The Tcl adapter writes EDIF, Yosys JSON and the matching `.pin` into `build/atf1508/`. Its mapping sequence follows the upstream flow; check the emitted top-level port names before fitting. Run FIT1508 in that output directory with the same basename for EDIF and `.pin`. A Windows command template is:

```text
fit1508.exe -i hp9835_unified_ram_rom_board_pinned.edif -ifmt edif -o hp9835_unified_ram_rom_board_pinned.jed -lib C:\path\to\aprim.lib -tech ATF1508AS -device TQFP100 -tpd <ACTUAL_DEVICE_SPEED_NS> -preassign KEEP -str JTAG=ON -str pin_keep=OFF -str pd1=OFF -str pd2=OFF -str open_collector=hp_mip_n
```

Replace the library path and speed placeholder with the installed library and purchased part's actual speed grade. On a Wine setup, invoke the same executable and arguments using Wine-compatible paths. `KEEP` prevents the fitter silently moving assigned pins. Keepers are disabled globally; switch pull-ups remain external. Only MIP is requested as open collector.

Do **not** call upstream `run_fitter.sh` unchanged on this VHDL design: that script regenerates/overwrites `.pin` by extracting `//PIN:` comments from a same-basename Verilog file. This project supplies `.pin` directly instead.

A successful command alone is insufficient. Inspect the `.fit` report for all assigned ports, TQFP100, correct global clocks, JTAG enabled, and **open collector on hp_mip_n only**. Confirm MEM_D remains high impedance during ordinary operation, including MEM_D15 (unused by the address latch), and that boundary scan can drive/capture the intended pins. FLASH_RYBY_N is functionally unused and FLASH_RESET_N constant-high in the core; inspect how the fitter treats them. `keep` attributes are not proof of boundary-scan programming behavior.

The pin-file syntax is taken from the upstream [mmu.v example](https://github.com/hoglet67/atf15xx_yosys/blob/master/examples/mmu/mmu.v). Pin locking and fitter options are documented in the [Microchip fitter guide](https://ww1.microchip.com/downloads/aemDocuments/documents/MPD/ProductDocuments/UserGuides/ATF15XX-ATF1500-CPLD-Fitter-User-Guide-DS20007127.pdf). No JEDEC or successful-fit claim is included in this repository.

Configuration update 2026-10-04: BASE_N[0..3] use pins 46,47,96,97; DIAG_N uses 98. DIP_N[9] remains wired to pole 10 but reserved pending A/B ROM mapping. Verify that unused-port optimization does not remove future configuration or required boundary-scan access. Three spare pads remain (85,99,100).
