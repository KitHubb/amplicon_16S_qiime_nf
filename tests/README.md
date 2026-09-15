# Primer regression test

From the repository root with Nextflow 26.04.2, Java 17+, and Docker:

```bash
nextflow run . -profile test,docker \
  -params-file params/examples/custom_primers.yml \
  --primer_f ACGTACGTACGT
python3 tests/check_trimmed.py results/primer-test
```

The public Cutadapt image is downloaded automatically. The YAML intentionally
provides a different forward primer so the CLI override verifies precedence.
The `test` profile alone supplies all synthetic inputs and primer settings.
Use `test,singularity` or `test,apptainer` with those runtimes instead.

To reuse a local SIF:

```bash
nextflow run . -profile test,singularity \
  --cutadapt_sif /absolute/path/to/read_cleanup_cutadapt-5.2.sif
python3 tests/check_trimmed.py results/primer-test
```

This checks both region defaults, legacy V1V3 adapters, single-direction
overrides, adapter overrides, IUPAC reverse complements, invalid inputs,
and (with the YAML/CLI command above) command-line precedence. It runs the real
Cutadapt module on synthetic paired reads. The verifier requires exactly one
record per mate, each with 60 T bases and 60 quality characters.
No project data or QIIME artifacts are used; the full QIIME 2 workflow and
other container tools are outside this smoke test's coverage.

GitHub Actions runs the Docker command and verifier on every push and PR.
Tagged releases are published only after the regression passes.
