"""Verify that both synthetic reads survived and were trimmed exactly."""
import gzip
import sys
from pathlib import Path

for mate in (1, 2):
    path = Path(sys.argv[1]) / '02_cutadapt_q20' / f'synthetic.R{mate}.trimmed.fastq.gz'
    with gzip.open(path, 'rt') as handle:
        lines = handle.read().splitlines()
    assert len(lines) == 4, f'{path}: expected exactly one FASTQ record'
    assert lines[0].startswith('@'), f'{path}: invalid FASTQ header'
    assert lines[1] == 'T' * 60, f'{path}: unexpected trimmed sequence'
    assert lines[2].startswith('+') and len(lines[3]) == 60, f'{path}: invalid quality record'
print('Both synthetic mates contain exactly 60 T bases')
