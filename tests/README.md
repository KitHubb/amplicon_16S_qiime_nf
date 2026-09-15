# Primer smoke test

From the repository root, run:

```bash
NXF_OFFLINE=true nextflow run tests/primers.nf -lib lib \
  -c nextflow.config \
  -params-file params/examples/custom_primers.yml \
  --primer_f ACGTACGTACGT \
  --test_r1 "$PWD/tests/fixtures/r1.fastq" \
  --test_r2 "$PWD/tests/fixtures/r2.fastq" \
  --outdir /tmp/amplicon-primer-test-results \
  -work-dir /tmp/amplicon-primer-test-work
```

This checks both region defaults, legacy V1V3 adapters, single-direction
overrides, adapter overrides, IUPAC reverse complements, invalid inputs,
and command-line precedence over an external YAML. It runs the real Cutadapt
module on synthetic paired reads. Both trimmed reads should contain exactly
60 T bases. No project data or QIIME artifacts are used.
