#!/usr/bin/env python3
"""Check Rev G programming, memory and power connectivity in a KiCad XML export.

Usage: python3 tools/check_programming.py exported-kicad.xml
This checks physical pad connectivity and population choices, not analog margins
or the CPLD fitting/programming algorithm.
"""
import csv
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
nets = {}
nodes = {}
components = {c.get('ref'): c for c in root.findall('./components/comp')}
for net in root.findall('./nets/net'):
    name = net.get('name').lstrip('/')
    members = {(n.get('ref'), n.get('pin')) for n in net.findall('node')}
    nodes[name] = members
    for member in members:
        nets[member] = name


def pin(ref, pad, expected):
    actual = nets.get((ref, str(pad)))
    assert actual == expected, (ref, pad, expected, actual)


for p, name in {1: 'TCK', 2: 'GND', 3: 'TDO', 4: '+5V',
                5: 'TMS', 9: 'TDI', 10: 'GND'}.items():
    pin('J2', p, name)
for p in (6, 7, 8):
    assert nets.get(('J2', str(p)), '').startswith('unconnected-')
fp = components['J2'].findtext('footprint')
assert fp == 'Connector_IDC:IDC-Header_2x05_P2.54mm_Vertical', fp

for p, name in {1: 'FTDI_OSCI', 2: 'FTDI_OSCO', 3: '+3V3', 5: 'FTDI_REF',
                6: 'USB_DM', 7: 'USB_DP', 8: '+3V3', 12: '+3V3',
                13: 'FTDI_TCK', 14: 'FTDI_TDI', 15: 'FTDI_TDO', 16: 'FTDI_TMS',
                24: '+3V3', 25: 'FTDI_JTAG_DISABLE', 28: 'FTDI_SIWU_N',
                32: 'USB_PWREN_N', 34: 'FTDI_RESET_N', 37: '+1V8_A', 38: '+1V8', 39: '+3V3',
                40: 'VBUS', 42: 'GND', 43: 'EE_DATA', 44: 'EE_CLK',
                45: 'EE_CS', 46: '+3V3'}.items():
    pin('U6', p, name)
for p in (4, 9, 10, 11, 22, 23, 35, 36, 41, 47, 48):
    pin('U6', p, 'GND')
assert nodes['+1V8_A'] == {('U6', '37'), ('C27', '1')}
assert nodes['+1V8'] == {('U6', '38'), ('C25', '1')}
pin('R24', 1, 'FTDI_REF')
pin('R24', 2, 'GND')
assert components['R24'].findtext('value') == '12k 1%'
for p, name in {1: 'EE_CS', 2: 'EE_CLK', 3: 'EE_DATA', 4: 'EE_DO',
                5: 'GND', 8: '+3V3'}.items():
    pin('U7', p, name)
pin('R27', 1, 'EE_DATA')
pin('R27', 2, 'EE_DO')
assert components['R27'].findtext('value') == '2k2'
pin('R28', 1, '+3V3')
pin('R28', 2, 'EE_DO')

# Buffer direction matters: three FTDI-to-target channels and one return path.
for p, name in {1: 'USB_JTAG_OE_N', 2: 'FTDI_TCK', 3: 'TCK',
                4: 'USB_JTAG_OE_N', 5: 'FTDI_TDI', 6: 'TDI', 7: 'GND',
                8: 'TMS', 9: 'FTDI_TMS', 10: 'USB_JTAG_OE_N',
                11: 'FTDI_TDO', 12: 'TDO', 13: 'USB_JTAG_OE_N', 14: '+3V3'}.items():
    pin('U8', p, name)
assert any(f.get('name') == 'Manufacturer' and f.text == 'Nexperia'
           for f in components['U8'].findall('./fields/field'))

for ref, source in [('D1', '+5V_HP'), ('D2', 'USB_TARGET_5V'), ('D3', '+5V_BENCH')]:
    pin(ref, 2, source)  # anode
    pin(ref, 1, '+5V')  # cathode
assert len({nets['D1', '2'], nets['D2', '2'], nets['D3', '2'], '+5V', 'VBUS'}) == 5
pin('J5', 1, '+5V_BENCH')
pin('J5', 2, 'GND')
for p, name in {1: 'VBUS', 2: 'GND', 3: 'USB_PWREN_N', 4: 'USB_FAULT_N',
                5: 'USB_ILIM', 6: 'USB_TARGET_5V'}.items():
    pin('U9', p, name)
assert components['R30'].findtext('value') == '88k7 1%'
for p, name in {1: 'USB_TARGET_BAD', 2: 'GND', 3: 'USB_REF_1V242',
                4: 'USB_LOCAL_SENSE', 5: 'USB_REF_1V242', 6: '+3V3'}.items():
    pin('U10', p, name)
for p, name in {1: 'USB_TARGET_BAD', 2: 'USB_PWREN_N', 3: 'GND',
                4: 'USB_JTAG_POWER_OFF', 5: '+3V3'}.items():
    pin('U11', p, name)
for p, name in {1: 'USB_JTAG_POWER_OFF', 2: 'FTDI_JTAG_DISABLE', 3: 'GND',
                4: 'USB_JTAG_OE_N', 5: '+3V3'}.items():
    pin('U15', p, name)
pin('R47', 1, '+3V3')
pin('R47', 2, 'FTDI_JTAG_DISABLE')
pin('R32', 1, '+5V')
pin('R32', 2, 'USB_LOCAL_SENSE')
pin('R33', 1, 'USB_LOCAL_SENSE')
pin('R33', 2, 'GND')

# Raw HP presence and manual PROGRAM independently disable both HP outputs.
for p, name in {1: 'HP_POWER_BAD', 2: 'GND', 3: 'HP_REF_1V242',
                4: 'HP_RAW_SENSE', 5: 'HP_REF_1V242', 6: '+5V'}.items():
    pin('U12', p, name)
pin('R36', 1, '+5V_HP')
pin('R36', 2, 'HP_RAW_SENSE')
pin('JP1', 1, 'PROGRAM')
pin('JP1', 2, 'GND')
pin('R39', 1, '+5V')
pin('R39', 2, 'PROGRAM')
for p, name in {1: 'HP_POWER_BAD', 2: 'PROGRAM', 3: 'HP_DISABLE',
                4: 'CPLD_XCVR_OE_N', 5: 'HP_DISABLE', 6: 'XCVR_OE_N',
                7: 'GND', 8: 'HP_MIP_GATE_N', 9: 'CPLD_MIP_N',
                10: 'HP_DISABLE', 12: 'GND', 13: 'GND', 14: '+5V'}.items():
    pin('U14', p, name)
for p, name in {2: 'HP_MIP_GATE_N', 3: 'GND', 4: 'HP_MIP_N', 5: '+5V_HP'}.items():
    pin('U13', p, name)
assert nodes['HP_MIP_N'] == {('J3', '40'), ('U13', '4')}
pin('U1', 35, 'CPLD_MIP_N')
pin('U1', 36, 'CPLD_XCVR_OE_N')
for ref, offset in [('U2', 0), ('U3', 8)]:
    pin(ref, 1, 'XCVR_DIR')
    pin(ref, 19, 'XCVR_OE_N')
    pin(ref, 20, '+5V')
    pin(ref, 10, 'GND')
    for i in range(8):
        pin(ref, i + 2, f'HP_IDA_N{i + offset}')
        pin(ref, 18 - i, f'MEM_D{i + offset}')

flash_a = [25, 24, 23, 22, 21, 20, 19, 18, 8, 7, 6, 5, 4, 3, 2, 1, 48, 17]
flash_d = [29, 31, 33, 35, 38, 40, 42, 44, 30, 32, 34, 36, 39, 41, 43, 45]
sram_a = [5, 4, 3, 2, 1, 44, 43, 42, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18]
sram_d = [7, 8, 9, 10, 13, 14, 15, 16, 29, 30, 31, 32, 35, 36, 37, 38]
for ref, addresses, data in [('U4', flash_a, flash_d), ('U5', sram_a, sram_d)]:
    for i, pad in enumerate(addresses):
        pin(ref, pad, f'MEM_A{i}')
    for i, pad in enumerate(data):
        pin(ref, pad, f'MEM_D{i}')
for p, name in {11: 'MEM_WE_N', 12: 'FLASH_RESET_N', 15: 'FLASH_RYBY_N',
                26: 'FLASH_CE_N', 27: 'GND', 28: 'MEM_OE_N',
                37: '+5V', 46: 'GND', 47: '+5V'}.items():
    pin('U4', p, name)
pin('R46', 1, '+5V')
pin('R46', 2, 'FLASH_RYBY_N')
pin('R49', 1, '+5V')
pin('R49', 2, 'XCVR_OE_N')
pin('R50', 1, '+5V')
pin('R50', 2, 'HP_MIP_GATE_N')
for p, name in {6: 'SRAM_CE_N', 11: '+5V', 12: 'GND', 17: 'MEM_WE_N',
                33: '+5V', 34: 'GND', 39: 'SRAM_BLE_N',
                40: 'SRAM_BHE_N', 41: 'MEM_OE_N'}.items():
    pin('U5', p, name)

population = Path(__file__).resolve().parents[1] / 'documentation/assembly_variants.csv'
rows = {r['Reference']: r for r in csv.DictReader(population.open())}
assert set(rows) == set(components), (set(rows) - set(components), set(components) - set(rows))
for ref, comp in components.items():
    row = rows[ref]
    assert row['Value'] == comp.findtext('value'), (ref, row['Value'], comp.findtext('value'))
    assert row['Footprint'] == comp.findtext('footprint'), ref
    for variant in ('USB', 'HEADER'):
        assert row[variant] == ('FIT' if row['Assembly'] in ('COMMON', variant) else 'DNP'), ref
assert rows['J2']['HEADER'] == 'FIT' and rows['J2']['USB'] == 'DNP'
assert rows['U6']['HEADER'] == 'DNP' and rows['U6']['USB'] == 'FIT'
for ref in ('U12', 'U13', 'U14', 'JP1', 'R10', 'R11', 'R12', 'R13', 'R14', 'R15'):
    assert rows[ref]['Assembly'] == 'COMMON', ref
print('PASS: 10-pin THT JTAG, FT232H/EEPROM, bidirectional JTAG isolation, source diodes,')
print('      USB enumeration/undervoltage/MPSSE gating, HP isolation, physical memory buses, assembly variants')
