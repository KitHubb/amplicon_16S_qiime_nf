# v0.0.9

- Download versioned BioContainers images for FastQC 0.12.1, MultiQC 1.27, and Cutadapt 5.2 automatically; use the official QIIME 2 amplicon 2025.7 image.
- Preserve optional local SIF overrides and document cache reuse.
- Add Docker, Apptainer, and synthetic primer test profiles alongside Singularity.
- Run primer regression and exact paired FASTQ output checks on GitHub Actions for pushes and pull requests; publish tagged releases after CI passes.
- Prefix trimming optimization output directories with `05_` and update documentation.

Validation covers synthetic primer handling and Cutadapt trimming, not full QIIME 2 analysis.
