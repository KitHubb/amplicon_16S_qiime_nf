"""Check actual outputs from all four container images after the test workflow."""
import runpy
import sys
from pathlib import Path
from zipfile import ZipFile

runpy.run_path(str(Path(__file__).with_name('check_trimmed.py')), run_name='__main__')
root = Path(sys.argv[1])
for mate in (1, 2):
    name = f'synthetic.R{mate}.trimmed_fastqc'
    with ZipFile(root / 'container_qc' / 'fastqc' / f'{name}.zip') as archive:
        assert any(p.endswith('/fastqc_data.txt') for p in archive.namelist())
report = root / 'container_qc' / 'multiqc' / 'multiqc_report.html'
assert report.stat().st_size > 0, f'Missing or empty report: {report}'
for name in ('demux-paired.qza', 'demux-summary.qzv'):
    with ZipFile(root / '04_qiime2_import' / name) as archive:
        assert archive.testzip() is None, f'Corrupt QIIME artifact: {name}'
        assert any(p.endswith('/metadata.yaml') for p in archive.namelist())
assert 'PASS: required QIIME actions are available' in (root / 'container_checks' / 'qiime-container.txt').read_text()
print('PASS: Cutadapt, FastQC, MultiQC, and QIIME 2 container outputs verified')
