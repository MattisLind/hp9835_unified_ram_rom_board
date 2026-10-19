# Configuration regression

Run from the repository root with GHDL on PATH:

```sh
python3 tools/test_logic.py
```

Or supply `--ghdl /absolute/path/to/ghdl`. The runner uses a temporary directory and tests the actual core RTL, not a separate behavioral implementation. Tested with GHDL 6.0.0 LLVM on macOS.

`tb_memory_configuration.vhd` checks every one of the 16 base settings against all 128 HP blocks at eight address boundaries, then exhausts all 32768 word addresses of special block 1. It also checks RAL exclusion, RAM disable, diagnostic enable exclusively from J4, diagnostic boundaries, base-relative addressing, PH2 write timing, and STM release.

For schematic checks, export a KiCad XML netlist and run:

```sh
python3 tools/check_memory_bus.py /path/to/schematic.xml
python3 tools/check_configuration.py /path/to/schematic.xml
python3 tools/generate_cpld_constraints.py --check --netlist /path/to/schematic.xml
```

Simulation and generic synthesis do not prove that the design fits the ATF1508, meets bus timing or programs flash correctly via EXTEST. A/B ROM selection remains deferred; pole 10 is reserved and intentionally has no effect.
