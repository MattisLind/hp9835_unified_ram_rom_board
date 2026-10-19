#!/usr/bin/env python3
"""Validate the CPU-sourced J3 pin map and isolated unused supplies/signals.
Usage: python3 tools/check_memory_bus.py exported-kicad.xml
Also run generate_cpld_constraints.py --check --netlist on the same export.
"""
import csv
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
nets = {}
for net in root.findall('./nets/net'):
    nodes = {(n.get('ref'), n.get('pin')) for n in net.findall('node')}
    for node in nodes:
        nets[node] = (net.get('name').lstrip('/'), nodes)
rows = list(csv.DictReader((Path(__file__).resolve().parents[1] /
                           'documentation/hp9835_connector_pinmap.csv').open()))
assert len(rows) == 50 and {int(r['pin']) for r in rows} == set(range(1, 51))
for row in rows:
    pin, expected = row['pin'], row['signal']
    name, nodes = nets.get(('J3', pin), ('', set()))
    if expected:
        assert name == expected, (pin, expected, name)
    else:
        assert pin == '36' and (not nodes or nodes == {('J3', pin)}), (pin, nodes)
for signal, pins in {'GND': [9,10,30,31,41,43,45,47,49], '+5V': [35,37,39],
                     '+12V': [27,29], '-12V': [28], '+7V': [50]}.items():
    for pin in pins:
        assert nets['J3', str(pin)][0] == signal
for pin, expected in [(33, 'HP_STME_N'), (38, 'HP_SUMC_N'), (28, '-12V'), (50, '+7V')]:
    assert nets['J3', str(pin)] == (expected, {('J3', str(pin))})
assert nets['J3', '27'][1] == {('J3', '27'), ('J3', '29')}
assert ('U1', '87') in nets['J3', '42'][1]
assert ('J3', '33') not in nets['J3', '42'][1]
assert ('U1', '35') in nets['J3', '40'][1]
assert ('J3', '38') not in nets['J3', '40'][1]
print('PASS: all 50 J3 contacts; supplies; separate STM/STME and MIP/SUMC; unused rails isolated')
