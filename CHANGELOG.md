# v0.1.0

- Configure local FastQC and MultiQC SIF/IMG files independently with `fastqc_sif` and `multiqc_sif`; replace the former shared QC image parameter with these two settings.
- Automatically download pinned public images for any tool without a local override.
- Test all four container images using synthetic reads: Cutadapt, FastQC, MultiQC, and QIIME 2 import/summary plus required plugin availability.
- Fix QIIME import shell quoting and configure a writable plotting cache.
- Verify generated reports and artifacts in CI before publishing the release.

Validation: all five smoke-test tasks and output verification passed with Singularity, including cold-cache public image retrieval, cache reuse, and separate server-local QC images. Full DADA2, taxonomy, phylogeny, and diversity analyses are outside smoke-test coverage.

# v0.0.9

- Download versioned BioContainers images for FastQC 0.12.1, MultiQC 1.27, and Cutadapt 5.2 automatically; use the official QIIME 2 amplicon 2025.7 image.
- Preserve optional local SIF overrides and document cache reuse.
- Add Docker, Apptainer, and synthetic primer test profiles alongside Singularity.
- Run primer regression and exact paired FASTQ output checks on GitHub Actions for pushes and pull requests; publish tagged releases after CI passes.
- Prefix trimming optimization output directories with `05_` and update documentation.

Validation covers synthetic primer handling and Cutadapt trimming, not full QIIME 2 analysis.
