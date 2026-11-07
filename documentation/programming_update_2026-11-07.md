# Revision G programming and power update — 2026-11-07

The KiCad schematic now implements the FT232H/header assembly choice and the isolated bench-power architecture. The [PDF](hp9835_unified_ram_rom_board_revG.pdf) contains five sheets: memory/CPLD, configuration/defaults, programming interfaces, power/isolation and bypassing.

## Assembly and use

- **USB:** fit the COMMON and USB rows in [assembly_variants.csv](assembly_variants.csv); omit J2. The schematic's DNP flags represent this default assembly.
- **HEADER:** fit COMMON and HEADER rows; omit USB-only parts. J2 is a keyed, shrouded 2x5 2.54mm **through-hole** IDC header. Its pinout is 1 TCK, 2 GND, 3 TDO, 4 target VCC, 5 TMS, 6-8 NC, 9 TDI, 10 GND.
- JP1 shunted is RUN; JP1 open is PROGRAM. Open JP1 before connecting a programmer. Programming is intended for the bench or an installed card with the HP off.
- The header variant needs a separately powered target. J5 is a regulated 5V bench input; pin 1 is positive, pin 2 ground. J2 pin 4 supplies the cable interface from the target, not the other way around. Include the ATDH1150USB cable's specified maximum 150mA target-side load when budgeting this variant.

The [ATDH1150USB guide](https://ww1.microchip.com/downloads/aemDocuments/documents/OTH/ProductDocuments/UserGuides/Atmel-8909-CPLD-ATDH1150USB-ATF15-JTAG-ISP-Download-Cable-UserGuide.pdf) defines the header pinout and target-power direction. A header-compatible programmer still needs device-appropriate programming software and 5V-compatible I/O.

## Implemented circuit

Local board power uses proper `+5V` symbols. The distinct raw HP rail uses a matching power arrow labelled `+5V_HP`; USB uses `VBUS`; FTDI supplies use `+3V3`, `+1V8` and the separate `+1V8_A`. Ground connections use native KiCad GND symbols. These names are real separate power nets, not aliases for one supply.

D1, D2 and D3 are PMEG2010ER Schottky diodes with their cathodes on local +5V. Their anodes are raw HP +5V, switched USB target power and J5 bench power respectively. This prevents one source from supplying another through the power contacts, apart from specified reverse leakage. Ground remains common.

U6 is an FT232HL with a 12MHz crystal, 93LC56B x16 EEPROM, 12k 1% reference resistor, reset pull-up, local bypassing and USBLC6 ESD protection. The project symbol corrects the standard library's EEPROM clock/select electrical directions and marks VCCD as an output for 5V operation. VCCA pin 37 and VCORE pin 38 are **separate 1.8V outputs**, each terminated only by its own 100nF capacitor; they are not joined or used to power other parts. See the [FT232H datasheet](https://ftdichip.cn/Support/Documents/DataSheets/ICs/DS_FT232H.pdf).

U8 must be the **Nexperia 74LVC125APW**, with documented Ioff and 5.5V input/output tolerance. It buffers TCK/TDI/TMS toward the target and TDO back to the FT232H. Its power-down behavior prevents the HP-powered target feeding the unpowered USB interface. See [Nexperia's datasheet](https://assets.nexperia.com/documents/data-sheet/74LVC125A.pdf); do not substitute a part based only on the `125` function number.

U9 is a TPS2552 with active-low enable from FT232H **ACBUS8/PWREN#**, physical pin 32. ACBUS8 remains a CBUS function in MPSSE mode; ACBUS0-7 become GPIO and are unsuitable for an independent enumeration/suspend power control. Its 88.7k 1% ILIM resistor gives approximately 299mA nominal target current limit (262-342mA across the manufacturer's tabulated tolerance). The USB-powered FTDI interface enumerates before the larger target load is enabled. Target limiting leaves part of the 500mA USB allocation for the interface; verify the complete load and inrush on hardware. [TI TPS2552 datasheet](https://www.ti.com/lit/ds/symlink/tps2552.pdf).

U10 and U11 keep U8 disabled until USB is configured and the local target supply exceeds a **nominal** approximately 4.56V threshold. The TLV3011B's 1.242V reference and 100k/37.4k 0.1% divider implement that threshold. This is a power-sequencing guard, not a precision guarantee of valid CPLD programming voltage; reference, offset, hysteresis and temperature tolerances still apply. [TI TLV3011B datasheet](https://www.ti.com/lit/ds/symlink/tlv3011.pdf).

U15 adds a host-controlled enable: ACBUS1/GPIOH1, physical pin 25, is pulled HIGH by R47 to keep U8 disabled during UART/reset. After selecting MPSSE, the host drives this pin LOW. This avoids driving the FT232H TDO/RTS# pad while it is still a UART output. The [OpenOCD adapter settings](../tools/openocd_ft232h.cfg) set data `0x0008` and directions `0x020b` after MPSSE initialization. They are an adapter configuration, not a complete ATF1508/Flash programming flow, and have not been exercised on hardware.

U12 senses **raw HP power**, independently of USB. U14 implements:

```text
HP_DISABLE    = HP_POWER_BAD OR PROGRAM
XCVR_OE_N     = CPLD_XCVR_OE_N OR HP_DISABLE
HP_MIP_GATE_N = CPLD_MIP_N OR HP_DISABLE
```

U13 is a 74LVC1G07 open-drain buffer powered from raw HP +5V. It releases physical HP MIP/ when that supply is absent and tolerates the separately powered input. No USB-fed pull-up connects to physical MIP/. U1 pin 35 remains open collector; the existing port now feeds `CPLD_MIP_N`. Pin 36 feeds `CPLD_XCVR_OE_N`. Neither the VHDL equations nor the fitted pad plan change. [TI 74LVC1G07 datasheet](https://www.ti.com/lit/ds/symlink/sn74lvc1g07.pdf).

## Existing wiring corrected

The redraw preserves the CPLD's pad plan and connector assignments, while separating raw HP power from local power. It also corrects U2/U3 to DIR on physical pad 1 and OE# on pad 19, and rewires both memories against their physical address/data/control pins. Flash RESET# is on pad 12, RY/BY# on pad 15, and BYTE# pad 47 is tied high for x16 mode. Flash/SRAM supply pads are explicitly connected. R15 adds the missing inactive MEM_OE# pull-up; R46 pulls up open-drain Flash RY/BY#. R49/R50 provide inactive defaults on the hardware-isolated outputs. The custom symbols, cached symbols and footprints agree.

## Checks and practical limits

Validation used KiCad CLI 10.0.5, a fresh XML export and the four scripts in [tests/README.md](../tests/README.md). The CPLD checker still verifies all 97 physical pad connections, with explicit net aliases for the two isolated requests. The new programming check includes all memory bus pads and the complete population table. All 112 components have existing footprints containing every symbol pad number. ERC and netlist artifacts are retained in [review_2026-11-07](review_2026-11-07).

ERC reports **0 errors and 4 warnings**, all single-pin labels on deliberately unused HP STME/, SUMC/, -12V and +7V connections. No pin/footprint mismatch or power-drive errors remain. The five PDF pages were rendered and visually checked.

The Schottky paths do not regulate voltage. The USB arrangement assumes the industrial 4.5V-minimum ATF1508AS; a commercial device requires at least 4.75V at its pins. Actual source/cable/diode losses must leave sufficient voltage for the CPLD, Flash, SRAM and HCT logic. Verify that margin under load, the USB pre-enumeration/suspend current, startup and source transitions, and installed-card backfeed before hardware sign-off. U14/U13 add propagation delay to OE and MIP; include this in HP bus timing validation. CPLD fit/timing and live Flash programming have not been demonstrated.

Before USB bench use, commission the EEPROM through USB with **bus-powered, 500mA requested, ACBUS8 = PWREN#, ACBUS1 = TriSt-PU**, an appropriate serial number and suspend/interface settings. Blank EEPROM leaves R26 holding target power disabled. This allows FTDI commissioning without powering the target. The Flash boundary-scan erase/write/read/verify tool remains to be implemented.
