# Primer and container smoke tests

From the repository root with Nextflow 26.04.2, Java 17+, and Docker:

```bash
nextflow run . -profile test,docker \
  -params-file params/examples/custom_primers.yml \
  --primer_f ACGTACGTACGT
python3 tests/check_containers.py results/primer-test
```

All four public images (Cutadapt, FastQC, MultiQC, and QIIME 2) are downloaded automatically on first use and cached. QIIME 2 can take several minutes to download. The YAML intentionally
provides a different forward primer so the CLI override verifies precedence.
The `test` profile alone supplies all synthetic inputs and primer settings.
Use `test,singularity` or `test,apptainer` with those runtimes instead.

To reuse separate local SIF/IMG images (omit any option to use its public image):

```bash
nextflow run . -profile test,singularity \
  --fastqc_sif /absolute/path/to/fastqc.sif \
  --multiqc_sif /absolute/path/to/multiqc.img \
  --cutadapt_sif /absolute/path/to/read_cleanup_cutadapt-5.2.sif \
  --qiime_sif /absolute/path/to/qiime2.sif
python3 tests/check_containers.py results/primer-test
```

This checks both region defaults, legacy V1V3 adapters, single-direction
overrides, adapter overrides, IUPAC reverse complements, invalid inputs,
and (with the YAML/CLI command above) command-line precedence. It runs the real
Cutadapt module on synthetic paired reads. The verifier requires exactly one
record per mate, each with 60 T bases and 60 quality characters.
It also runs the real FastQC and MultiQC modules, imports the trimmed reads
with QIIME 2, creates a demux summary, and checks availability of the DADA2,
feature-classifier, phylogeny, diversity, and taxa actions. The output verifier
checks FastQC ZIPs, the MultiQC report, QIIME artifacts, and the plugin check log.
No project data or existing QIIME artifacts are required. Plugin availability
checks do not run full denoising, classification, phylogeny, or diversity analyses.

To test public image retrieval, omit all `*_sif` overrides. To exercise a fresh
Singularity image cache, set `NXF_SINGULARITY_CACHEDIR` to a new writable directory.
Rerun without `-resume` to execute every tool again using cached images; `-resume`
may reuse completed task outputs instead. A successful Nextflow run must finish
with all five tasks completed (Cutadapt, FastQC, MultiQC, QIIME import, plugin check).

External users can run the same test directly from GitHub after these changes
are published:

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r main -latest -profile test,docker
```

Reports are written to `results/primer-test/container_qc/`, QIIME artifacts to
`results/primer-test/04_qiime2_import/`, and the plugin log to
`results/primer-test/container_checks/qiime-container.txt`.

GitHub Actions runs the Docker command and verifier on every push and PR.
Tagged releases are published only after the regression passes.
