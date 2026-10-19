#!/usr/bin/env python3
"""Run the configuration regression using GHDL (no target fitter required)."""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ghdl', default=shutil.which('ghdl'), help='GHDL executable path')
args = parser.parse_args()
if not args.ghdl:
    parser.error('GHDL is not on PATH; supply --ghdl /path/to/ghdl')
exe = str(Path(args.ghdl).resolve())
with tempfile.TemporaryDirectory(prefix='hp9835-logic-') as directory:
    def run(arguments):
        result = subprocess.run([exe, *arguments], cwd=directory,
                                text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode:
            raise SystemExit(result.stdout + result.stderr)
        if result.stdout:
            print(result.stdout, end='')
    run(['-a', '--std=08', str(root/'logic/hp9835_unified_ram_rom_board.vhd'),
         str(root/'logic/hp9835_unified_ram_rom_board_pinned.vhd'),
         str(root/'tests/tb_memory_configuration.vhd')])
    run(['-e', '--std=08', 'tb_memory_configuration'])
    run(['-r', '--std=08', 'tb_memory_configuration', '--assert-level=error',
         '--ieee-asserts=disable-at-0'])
