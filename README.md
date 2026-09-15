# amplicon_16S_qiime_nf

A modular Nextflow DSL2 workflow for paired-end 16S rRNA V1–V3 amplicon sequencing analysis using Cutadapt, FastQC, MultiQC, QIIME 2, DADA2, SILVA taxonomy, phylogenetic reconstruction, and alpha/beta diversity analysis.

## Overview

The workflow processes paired-end Illumina FASTQ files from raw-read quality control through ASV inference, taxonomic classification, phylogenetic reconstruction, and diversity analysis.

```text
Paired-end FASTQ
    |
    |-- Raw FastQC / MultiQC
    |
    |-- Cutadapt
    |   |-- V1-V3 primer trimming
    |   |-- Q20 quality trimming
    |   |-- Minimum-length filtering
    |   `-- Untrimmed-read removal
    |
    |-- Clean FastQC / MultiQC
    |
    |-- QIIME 2 paired-end import
    |
    |-- DADA2
    |   |-- Quality filtering
    |   |-- Error correction
    |   |-- Paired-end merging
    |   `-- Chimera removal
    |
    |-- SILVA taxonomy classification
    |
    |-- MAFFT alignment and FastTree phylogeny
    |
    `-- Alpha and beta diversity
        |-- Faith's phylogenetic diversity
        |-- Observed features
        |-- Shannon diversity
        |-- Pielou's evenness
        |-- Bray-Curtis
        |-- Jaccard
        |-- Weighted UniFrac
        |-- Unweighted UniFrac
        |-- PCoA
        `-- Emperor plots
```

## Pipeline structure

```text
.
|-- main.nf
|-- nextflow.config
|-- nextflow_schema.json
|-- conf/
|   `-- base.config
|-- params/
|   `-- v1v3_q20.yml
|-- modules/local/
|   |-- fastqc.nf
|   |-- multiqc.nf
|   |-- cutadapt_v1v3.nf
|   |-- qiime_import.nf
|   |-- qiime_dada2.nf
|   |-- qiime_taxonomy.nf
|   |-- qiime_phylogeny.nf
|   `-- qiime_diversity.nf
`-- subworkflows/local/
    |-- raw_qc.nf
    |-- read_cleanup.nf
    |-- clean_qc.nf
    |-- qiime_import.nf
    |-- qiime_dada2.nf
    |-- qiime_taxonomy.nf
    |-- qiime_phylogeny.nf
    `-- qiime_diversity.nf
```

## Requirements

- Linux
- Nextflow 26.04.2 or later
- Singularity or Apptainer
- Paired-end Illumina FASTQ files
- A QIIME 2-compatible SILVA classifier
- A QIIME 2-compatible metadata TSV file

The workflow uses separate containers for:

- FastQC and MultiQC
- Cutadapt
- QIIME 2 Amplicon

Container and classifier paths must be configured for the local computing environment.

## Input data

Paired FASTQ files are detected with a Nextflow file-pair pattern.

Example filenames:

```text
Sample01_1.fastq.gz
Sample01_2.fastq.gz
Sample02_1.fastq.gz
Sample02_2.fastq.gz
```

Example input pattern:

```bash
--reads '/data/FASTQ/project/*_{1,2}.fastq.gz'
```

If the files use names such as `_R1_001.fastq.gz` and `_R2_001.fastq.gz`, adjust the input glob accordingly.

## Metadata

The first metadata column must be `sample-id`, and its values must match the FASTQ sample IDs produced by `Channel.fromFilePairs`.

```text
sample-id    subject-id    swab-type    site-id    control-status
Sample01     S001          Copan        Ac         sample
Sample02     Control       Puritan      NC         negative-control
```

Provide the metadata file with:

```bash
--metadata /path/to/metadata.tsv
```

Do not commit participant metadata or direct identifiers to a public repository.

## V1–V3 primer configuration

Default Cutadapt sequences:

```text
Forward primer (-g):
AGAGTTTGATCCTGGCTCAG

Forward read-through sequence (-a):
CCAGCAGCCGCGGTAAT

Reverse primer (-G):
ATTACCGCGGCTGCTGG

Reverse read-through sequence (-A):
CTGAGCCAGGATCAAACTCT
```

Default filtering:

```text
Quality cutoff: Q20 for R1 and R2
Minimum length: 50 bp
Adapter search rounds: 2
Discard untrimmed reads: enabled
```

These settings can be changed in `params/v1v3_q20.yml` or overridden on the command line.

## Usage

```bash
nextflow run /path/to/amplicon_16S_v1v3_qiime_nf/main.nf \
  -profile singularity \
  -params-file /path/to/amplicon_16S_v1v3_qiime_nf/params/v1v3_q20.yml \
  --reads '/data/FASTQ/project/*_{1,2}.fastq.gz' \
  --metadata /path/to/metadata.tsv \
  --classifier /path/to/silva-classifier.qza \
  --sampling_depth 1000 \
  --outdir /path/to/results \
  -work-dir /path/to/work \
  -resume
```

Use the same work directory with `-resume` to reuse successfully completed tasks.

To run through phylogeny while skipping alpha/beta diversity, add:

```bash
--diversity_enabled false
```

## Major outputs

```text
results/
|-- 01_raw_qc/
|-- 02_cutadapt_q20/
|-- 03_clean_qc/
|-- 04_qiime2_import/
|-- 05_dada2/
|-- 06_taxonomy/
|-- 07_phylogeny/
`-- 08_diversity/
```

### Raw and cleaned-read quality control

```text
01_raw_qc/
|-- fastqc/
`-- multiqc/

03_clean_qc/
|-- fastqc/
`-- multiqc/
```

### Cutadapt

```text
02_cutadapt_q20/
|-- SAMPLE.R1.trimmed.fastq.gz
|-- SAMPLE.R2.trimmed.fastq.gz
|-- SAMPLE.cutadapt.json
`-- SAMPLE.cutadapt.log
```

### QIIME 2 import

```text
04_qiime2_import/
|-- manifest.tsv
|-- demux-paired.qza
`-- demux-summary.qzv
```

### DADA2

```text
05_dada2/
|-- table.qza
|-- rep-seqs.qza
|-- denoising-stats.qza
|-- denoising-stats.qzv
|-- table-summary.qzv
`-- rep-seqs.qzv
```

### Taxonomy

```text
06_taxonomy/
|-- taxonomy.qza
|-- taxonomy.qzv
`-- taxa-bar-plots.qzv
```

### Phylogeny

```text
07_phylogeny/
|-- aligned-rep-seqs.qza
|-- masked-aligned-rep-seqs.qza
|-- unrooted-tree.qza
`-- rooted-tree.qza
```

### Diversity

```text
08_diversity/
|-- core-metrics-results/
|-- alpha-rarefaction.qzv
|-- faith-pd-group-significance.qzv
|-- observed-group-significance.qzv
|-- shannon-group-significance.qzv
`-- evenness-group-significance.qzv
```

The core metrics directory includes:

- Bray-Curtis and Jaccard distance matrices
- Weighted and unweighted UniFrac distance matrices
- PCoA results
- Emperor visualizations
- Faith's PD, observed features, Shannon diversity, and evenness vectors

## DADA2 defaults

```yaml
dada2_trunc_len_f: 0
dada2_trunc_len_r: 0
dada2_max_ee_f: 2
dada2_max_ee_r: 4
```

Fixed truncation is disabled because Cutadapt performs Q20 trimming before QIIME 2 import. V1–V3 amplicons are relatively long, so reverse-read quality and retained read length should be reviewed before final analysis.

## Sampling depth

The initial diversity sampling depth is:

```yaml
sampling_depth: 1000
```

This is an initial value, not a universal recommendation. Review `05_dada2/table-summary.qzv` and choose an appropriate sampling depth based on retained sample frequencies before the final diversity analysis.

## Important considerations

- V1–V3 amplicons are relatively long, so reverse-read quality can strongly affect paired-end merging.
- `--discard-untrimmed` can remove reads containing primer mismatches.
- DADA2 truncation lengths are initially set to zero because Cutadapt performs quality trimming.
- The SILVA classifier must be compatible with the installed QIIME 2 version.
- A V1–V3 region-specific classifier may improve taxonomic classification.
- Negative controls should be retained and evaluated during contamination assessment.
- Metadata sample IDs must exactly match the imported QIIME sample IDs.

## Reproducibility

The workflow records versions for:

- FastQC
- MultiQC
- Cutadapt
- QIIME 2

Pin container image versions and the exact classifier artifact used for publication analyses.

## Repository exclusions

Do not commit raw sequencing data, QIIME artifacts, containers, work directories, or participant metadata.

Recommended `.gitignore` entries:

```gitignore
# Nextflow
.nextflow/
.nextflow.log*
work/

# Pipeline outputs
results/
Output/

# Sequencing data
*.fastq
*.fastq.gz
*.fq
*.fq.gz

# QIIME 2 artifacts
*.qza
*.qzv

# Containers
*.sif
*.img
*.simg

# Metadata and private data
*metadata*.tsv
*metadata*.xlsx
Input/

# OS and editors
.DS_Store
Thumbs.db
.vscode/
.idea/
```

## License

MIT License is recommended unless institutional or dependency-specific requirements apply.

## Citation

If you use this workflow, cite the underlying tools and databases:

- Nextflow
- FastQC
- MultiQC
- Cutadapt
- QIIME 2
- DADA2
- SILVA
- MAFFT
- FastTree

A dedicated `CITATIONS.md` with versions, DOIs, and URLs is recommended for publication use.

## Optional DADA2 truncation optimization

Enable the parameter sweep with `--trimm_optimal true`. Candidate forward/reverse
truncation lengths are read from the tab-delimited file specified by
`--trimm_combinations`. The required columns are `name`, `trunc_len_f`, and
`trunc_len_r`; the default ten-condition file is `params/trimm_combinations_10bp.tsv`.
Every candidate must have a forward length greater than its reverse length, and
both values must use 10-nt increments. Invalid rows stop the workflow before the
DADA2 sweep begins.

Use `--taxonomy_label SILVA` or `--taxonomy_label GG2` when comparing classifiers.
The label is included in the Nextflow task cache key, preventing taxonomy results
from one classifier from being reused for another. `AUTO` infers SILVA, GG2, or
GTDB from the classifier path.

Each candidate is denoised independently and classified with the supplied SILVA
classifier at a fixed confidence threshold. All successfully completed candidates
are retained in the comparison table. Low-depth and zero-merge sample counts are
reported as descriptive columns and are not used to remove candidates. Ranking is
ordered by:

1. Species-assigned reads as a percentage of DADA2 input reads.
2. Species-assigned reads as a percentage of the feature table.
3. Overall non-chimeric retention.

Example:

```bash
nextflow run /data/software/nextflow/amplicon_16S_v1v3_qiime_nf/main.nf \
  -profile singularity \
  -params-file /data/software/nextflow/amplicon_16S_v1v3_qiime_nf/params/v1v3_q20.yml \
  --reads '/data/FASTQ/HN00182797/DT/*_{1,2}.fastq.gz' \
  --run_label HN00182797 \
  --outdir /data/home2/ksy/260811_DT_swab/Output/HN00182797 \
  --classifier /data/Reference/QIIME2-2025.7/Bacteria/SILVA/silva-138-99-nb-classifier.qza \
  --taxonomy_label SILVA \
  --metadata /data/home2/ksy/260811_DT_swab/Input/DT_metadata_qiime.tsv \
  --trimm_optimal true \
  --trimm_combinations /data/software/nextflow/amplicon_16S_v1v3_qiime_nf/params/trimm_combinations_10bp.tsv \
  --diversity_enabled false \
  -work-dir /data/home2/ksy/260811_DT_swab/work/HN00182797 \
  -resume
```

The comparison and selected artifacts are written below:

```text
trimm_optimal_SILVA/selected/
├── all_parameter_results.tsv
├── optimal_selection.tsv
├── optimal_truncation.txt
├── selected-table.qza
├── selected-rep-seqs.qza
└── selected-denoising-stats.qza
```

Using `--taxonomy_label GG2` writes the corresponding comparison to
`trimm_optimal_GG2/selected/`. DADA2 sweep artifacts shared across classifiers are
written to `trimm_optimal_dada2/`. Final classifier outputs are named
`06_taxonomy/taxonomy_<LABEL>.qza` and `taxa-bar-plots_<LABEL>.qzv`.
