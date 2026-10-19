#!/usr/bin/env python3
"""Check switch/header/pull-up wiring in a KiCad XML export."""
import sys
import xml.etree.ElementTree as ET

nets = {}
for net in ET.parse(sys.argv[1]).findall('./nets/net'):
    nodes = {(n.get('ref'), n.get('pin')) for n in net.findall('node')}
    for node in nodes:
        nets[node] = (net.get('name').lstrip('/'), nodes)
for i in range(12):
    name, nodes = nets['SW2', str(i+1)]
    assert name == f'DIP_N{i}', (i+1, name)
    assert nets['SW2', str(24-i)][0] == 'GND'
    assert any(ref.startswith('R') for ref, _ in nodes), ('missing pull-up', name)
for i, pad in enumerate([46,47,96,97]):
    expected = {(f'R{19+i}', '2'), ('SW3', str(i+1)), ('U1', str(pad))}
    assert nets['SW3', str(i+1)] == (f'BASE_N{i}', expected)
    assert nets['SW3', str(8-i)][0] == 'GND'
    assert nets[f'R{19+i}', '1'][0] == '+5V'
assert nets['J4','1'] == ('DIAG_N', {('J4','1'), ('R23','2'), ('U1','98')})
assert nets['J4','2'][0] == 'GND' and nets['R23','1'][0] == '+5V'
assert nets['SW2','10'][0] == 'DIP_N9'  # reserved A/B pole, not diagnostic
print('PASS: 12 configuration poles, 4 base poles, 5 pull-ups, remote diagnostic header')
