# amplicon_16S_qiime_nf

[English](#english) · [한국어](#korean)

<a id="english"></a>

## English

### Contents

1. [Quick start](#en-start)
2. [FASTQ and metadata](#en-inputs)
3. [Region and primers](#en-primers)
4. [Truncation optimization](#en-optimization)
5. [Containers and cache](#en-containers)
6. [Server resources](#en-resources)
7. [Analysis settings and customization](#en-options)
8. [Results](#en-outputs)
9. [Tests and releases](#en-tests)
10. [Code structure](#en-structure)

<a id="en-start"></a>

### 1. Quick start

This pipeline analyzes Illumina paired-end 16S rRNA reads from the V1V3 or V3V4 region. It can compare DADA2 forward/reverse truncation lengths, select the highest-ranked completed candidate, and use its ASVs for downstream analysis.

**Workflow:** FASTQ → FastQC/MultiQC → Cutadapt → FastQC/MultiQC → QIIME 2 import → DADA2 (fixed lengths or candidate comparison) → taxonomy → MAFFT/FastTree → diversity.

Use Linux, Java 17+, Nextflow 26.04.2 or later (tested with 26.04.2), and one container runtime: Docker, Singularity, or Apptainer. Prepare your FASTQ files, metadata TSV, and a classifier QZA compatible with QIIME 2 amplicon 2025.7. SILVA, GG2, or other compatible classifiers can be used.

Create an external `analysis.yml` (the filename `nextflow_params.yml` also works). Replace the example paths with your own:

```yaml
region: V3V4
reads: "/path/to/reads/*_{1,2}.fastq.gz"
metadata: "/path/to/metadata.tsv"
classifier: "/path/to/classifier.qza"
outdir: "/path/to/results"
run_label: "experiment01"
trimm_optimal: true
taxonomy_label: SILVA
taxonomy_confidence: 0.7
diversity_enabled: true
sampling_depth: 1000
```

Run the released pipeline directly from GitHub; cloning the repository is optional:

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile singularity \
  -params-file /path/to/analysis.yml \
  -work-dir /path/to/work
```

Choose `-profile docker`, `-profile singularity` (the default runtime), or `-profile apptainer`. Images are downloaded on first use and cached. Analysis tools do not need separate host installations.

For a local checkout:

```bash
nextflow run /path/to/amplicon_16S_qiime_nf/main.nf \
  -profile singularity -params-file /path/to/analysis.yml \
  -work-dir /path/to/work
```

Use `region: V1V3` for V1V3 data. Leave `trimm_combinations` unset to use the region's default candidates. This example enables optimization; the code default for `trimm_optimal` is `false`.

Set `diversity_enabled: false` to skip diversity analysis. Adjust `sampling_depth` to your sample read counts. To resume an analysis, keep the same launch directory and work directory and add `-resume`. Changed inputs, options, or module structure can cause tasks to run again. For the latest development code, replace `-r v0.1.0` with `-r main -latest`.

<a id="en-inputs"></a>

### 2. FASTQ and metadata

The workflow pairs reads using the filename pattern in `reads` and takes sample annotations from `metadata`. It does **not** accept a CSV samplesheet of FASTQ paths through `--input` or `--samplesheet`. The QIIME 2 import manifest is generated automatically after Cutadapt.

Prepare one R1/R2 pair per sample:

```text
reads/
  S01_1.fastq.gz
  S01_2.fastq.gz
  S02_1.fastq.gz
  S02_2.fastq.gz
```

For these files, use `reads: "/path/to/reads/*_{1,2}.fastq.gz"`. The extracted sample IDs are `S01` and `S02`. For filenames ending in `_R1_001.fastq.gz` and `_R2_001.fastq.gz`, use `*_{R1,R2}_001.fastq.gz` instead.

Prepare a tab-separated metadata file with `sample-id` as the first column:

```tsv
sample-id	group
S01	control
S02	treatment
```

To create this example with actual tab characters:

```bash
printf 'sample-id\tgroup\nS01\tcontrol\nS02\ttreatment\n' > metadata.tsv
```

Set `metadata` in your analysis YAML to the file's absolute path. Sample IDs must be unique and exactly match the IDs extracted from the filenames. Replace or extend the example `group` column with your experiment's conditions and batches. Use tabs, not commas or spaces. Run V1V3 and V3V4 separately with their corresponding reads and metadata.

<a id="en-primers"></a>

### 3. Region and primers

The default region is V1V3.

| Region | Forward primer (5′→3′) | Reverse primer (5′→3′) |
|---|---|---|
| V1V3 | `AGAGTTTGATCCTGGCTCAG` | `ATTACCGCGGCTGCTGG` |
| V3V4 | `CCTACGGGNGGCWGCAG` | `GACTACHVGGGTATCTAATCC` |

Choose `--region V3V4`, use a YAML preset from [params/regions](params/regions), or add explicit primer options to your run command:

```bash
--region V3V4 --primer_f 'CCTACGGGNGGCWGCAG' --primer_r 'GACTACHVGGGTATCTAATCC'
```

**Priority: command line > external parameter YAML > region defaults.** Overriding one primer leaves the other at its region default. See [custom_primers.yml](params/examples/custom_primers.yml) for a YAML example.

Primers accept IUPAC DNA letters, including lowercase. Read-through adapters are the reverse complements of the opposite primers unless `adapter_f` or `adapter_r` is set explicitly. Default V1V3 primers retain the adapters `CCAGCAGCCGCGGTAAT` and `CTGAGCCAGGATCAAACTCT`. The final sequences are printed in the run log.

<a id="en-optimization"></a>

### 4. Truncation optimization

Set `trimm_optimal: true` to enable candidate comparison. Truncation lengths apply to the reads imported into QIIME 2 after Cutadapt.

1. Run DADA2 independently for each forward/reverse pair in the candidate TSV.
2. Classify candidate ASVs and calculate read-retention and species-assignment metrics.
3. Rank completed candidates by the criteria below, in descending order. Later criteria break ties.
4. Pass the highest-ranked feature table and representative sequences to taxonomy, phylogeny, and diversity analysis.

| Priority | Metric | Calculation |
|---|---|---|
| 1 | `species_input_yield` | Species-assigned reads / DADA2 input reads × 100 |
| 2 | `species_read_pct` | Species-assigned reads / final feature-table reads × 100 |
| 3 | `nonchimeric_pct` | Non-chimeric reads / DADA2 input reads × 100 |

“Optimal” means best among the supplied candidates for the chosen classifier and ranking criteria. It does not establish a universal biological optimum. Metrics are aggregated across the dataset, rather than ranked per sample. Species detection uses `s__` or `s:` taxonomy markers and excludes names such as unknown and uncultured.

The region selects [v1v3_10bp.tsv](params/trimming/v1v3_10bp.tsv) (6 candidates) or [v3v4_10bp.tsv](params/trimming/v3v4_10bp.tsv) (10 candidates). Override it with `trimm_combinations: "/path/to/candidates.tsv"` or `--trimm_combinations /path/to/candidates.tsv`:

```tsv
name	trunc_len_f	trunc_len_r
F280_R270	280	270
F280_R260	280	260
F270_R250	270	250
```

Use actual tabs and unique candidate names. Current validation requires **F > R** and both lengths in **10-nt increments**. Default candidate design uses F + R − 20 ≥ 500 bp for V1V3 and ≥ 460 bp for V3V4. Both standard and optimization DADA2 use a minimum overlap of 12 bp. These design bounds are not verified biological maxima; adjust candidates to your read lengths and quality. See the [candidate design notes](params/trimming/README.md) for sources, length assumptions, and overlap calculations.

Candidates with failed DADA2 or taxonomy tasks are excluded. Selection fails if no candidates succeed. `optimal_min_sample_reads` defaults to 10000: low-read and zero-merge sample counts are reported but do not filter or rank candidates.

For fixed-length analysis, set `trimm_optimal: false` and use `dada2_trunc_len_f` and `dada2_trunc_len_r`. Their default value, `0`, disables fixed-length truncation. Optimization uses the TSV lengths instead of these two parameters.

<a id="en-containers"></a>

### 5. Containers and cache

Each tool uses a pinned public image unless you supply a local override.

| Tool | Public image | Local SIF/IMG parameter |
|---|---|---|
| FastQC | `quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0` | `fastqc_sif` |
| MultiQC | `quay.io/biocontainers/multiqc:1.27--pyhdfd78af_0` | `multiqc_sif` |
| Cutadapt | `quay.io/biocontainers/cutadapt:5.2--py311hc303176_2` | `cutadapt_sif` |
| QIIME 2 | `quay.io/qiime2/amplicon:2025.7` | `qiime_sif` |

FastQC and MultiQC use separate images and separate settings. The combined QC image and shared path setting are no longer used. QIIME 2 analysis steps share one QIIME 2 image.

To use existing images, add any of these settings to `analysis.yml` or `nextflow_params.yml`:

```yaml
fastqc_sif: "/absolute/path/to/fastqc.sif"
multiqc_sif: "/absolute/path/to/multiqc.img"
cutadapt_sif: "/absolute/path/to/cutadapt.sif"
qiime_sif: "/absolute/path/to/qiime2.sif"
```

Use `-profile singularity` or `-profile apptainer` for local SIF/IMG files. The image must be readable by that runtime; Docker cannot use these files. Omit a tool's setting to download its public image automatically. A local override takes priority for that tool only.

First use requires registry access and enough disk space, especially for QIIME 2. Singularity/Apptainer image references use `docker://`; Docker references omit that prefix. See the [Nextflow container documentation](https://docs.seqera.io/nextflow/container/singularity).

Set a persistent Singularity image cache before running:

```bash
export NXF_SINGULARITY_CACHEDIR=/path/to/container-cache
mkdir -p "$NXF_SINGULARITY_CACHEDIR"
```

For Apptainer, use `NXF_APPTAINER_CACHEDIR`. Docker manages its own image storage. On HPC, use a writable cache shared by all compute nodes. Image cache reuse avoids downloading images again; `-resume` separately controls reuse of completed task results.

**Existing lab server configuration.** Add these QC paths to your analysis YAML while retaining the reads, metadata, classifier, and other analysis settings:

```yaml
fastqc_sif: "/data/software/singularity/quay.io-biocontainers-fastqc-0.12.1--hdfd78af_0.img"
multiqc_sif: "/data/software/singularity/quay.io-biocontainers-multiqc-1.27--pyhdfd78af_0.img"
```

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile singularity -params-file /path/to/nextflow_params.yml
```

This server also has `/data/software/singularity/amplicon_16S_qc.config` with the same QC paths. To test it:

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile test,singularity \
  -c /data/software/singularity/amplicon_16S_qc.config
```

These absolute paths and the config file are specific to this server. Other users should set their own local paths or omit overrides to use automatic downloads.

<a id="en-resources"></a>

### 6. Server resources

Keep data paths and analysis parameters in an external YAML. Use an external `site.config` for the executor, queue, CPU, memory, and time limits. The default executor in [nextflow.config](nextflow.config) is `local`.

[conf/base.config](conf/base.config) defines these per-task defaults:

| Label | CPUs | Memory | Time |
|---|---|---|---|
| `process_low` | 8 | 16 GB | 12 h |
| `process_medium` | 8 | 24 GB | 24 h |
| `process_high` | 16 | 64 GB | 72 h |

Optimization candidates can run concurrently. Adjust resources for your server and dataset. Example `site.config`:

```groovy
process {
    executor = 'local'
    maxForks = 1
    withLabel: process_low {
        cpus = 2
        memory = '4 GB'
    }
    withLabel: process_medium {
        cpus = 4
        memory = '8 GB'
    }
    withLabel: process_high {
        cpus = 8
        memory = '32 GB'
    }
}
```

Add `-c /path/to/site.config` to the run command. The values above illustrate the syntax; they are not suitable for every dataset. `maxForks` limits concurrency per process, not across all processes combined. Set the scheduler and queue to match your institution's HPC configuration. Set the work directory with `-work-dir`.

<a id="en-options"></a>

### 7. Analysis settings and customization

Use parameters first. Edit tool modules when you need to change commands or logic.

| Purpose | Parameters or defaults | Implementation |
|---|---|---|
| FastQC / MultiQC | Image overrides and CPU settings | [fastqc.nf](modules/fastqc.nf), [multiqc.nf](modules/multiqc.nf) |
| Region, primers, adapters | `region`, `primer_f`, `primer_r`, `adapter_f`, `adapter_r` | [PrimerConfig.groovy](lib/PrimerConfig.groovy) |
| Cutadapt filtering | `quality: 20`, `min_length: 50` | [cutadapt.nf](modules/cutadapt.nf); includes `-n 2`, `--discard-untrimmed` |
| QIIME import | `reads` filename pattern | [qiime_import.nf](modules/qiime_import.nf) |
| Fixed DADA2 | `dada2_trunc_len_f: 0`, `dada2_trunc_len_r: 0`, `dada2_max_ee_f: 2`, `dada2_max_ee_r: 4` | [qiime_dada2.nf](modules/qiime_dada2.nf) |
| Candidate validation | `trimm_optimal`, `trimm_combinations` | [subworkflows/trimm_optimal.nf](subworkflows/trimm_optimal.nf), [params/trimming](params/trimming) |
| Candidate execution | The same `dada2_max_ee_*` settings | `DADA2_TRIMM_SWEEP` in [modules/trimm_optimal.nf](modules/trimm_optimal.nf) |
| Ranking and species rules | `optimal_min_sample_reads: 10000` changes reporting only | `TAXONOMY_TRIMM_SWEEP`, `SELECT_TRIMM_OPTIMAL` in the same module |
| Taxonomy | `classifier`, `taxonomy_confidence: 0.7`, `taxonomy_label: AUTO` | [qiime_taxonomy.nf](modules/qiime_taxonomy.nf) and candidate taxonomy in `modules/trimm_optimal.nf` |
| MAFFT / FastTree | No separate analysis parameters | [qiime_phylogeny.nf](modules/qiime_phylogeny.nf) |
| Diversity / rarefaction | `diversity_enabled: true`, `sampling_depth: 1000`, `alpha_max_depth: 10000` | [qiime_diversity.nf](modules/qiime_diversity.nf) |

For hard-coded DADA2 options such as `trunc-q` or chimera handling, check both standard and optimization modules. Keep candidate and final taxonomy commands consistent. When adding a parameter, update [nextflow.config](nextflow.config), [nextflow_schema.json](nextflow_schema.json), the relevant module, and both README language sections.

When changing image versions, check command options and classifier compatibility. Record the image versions and classifier used for the final analysis.

<a id="en-outputs"></a>

### 8. Results

All results are written under `outdir`.

| Directory | Contents |
|---|---|
| `01_raw_qc/`, `03_clean_qc/` | FastQC/MultiQC before and after filtering |
| `02_cutadapt_q20/` | Trimmed FASTQ, Cutadapt logs and JSON; the directory name is fixed even if `quality` changes |
| `04_qiime2_import/` | Manifest, paired-end QZA, quality summary |
| `05_dada2/` | Standard DADA2 results and summaries when optimization is disabled |
| `05_trimm_optimal_dada2/` | DADA2 outputs for each candidate |
| `05_trimm_optimal_<LABEL>/` | Candidate taxonomy and metrics |
| `05_trimm_optimal_<LABEL>/selected/` | Full ranking, selected lengths, selected QZA files |
| `06_taxonomy/` | Outputs such as `taxonomy_<LABEL>.qza` and `taxa-bar-plots_<LABEL>.qzv` |
| `07_phylogeny/`, `08_diversity/` | Phylogeny and, if enabled, diversity results |

After optimization, review:

- `all_parameter_results.tsv`: rankings and metrics for successful candidates.
- `optimal_selection.tsv` and `optimal_truncation.txt`: selected F/R lengths and scores.
- `selected-table.qza`, `selected-rep-seqs.qza`, and `selected-denoising-stats.qza`: artifacts passed to downstream analysis.

`taxonomy_label: AUTO` infers labels such as SILVA, GG2, or GTDB from the classifier path. Set an explicit label to distinguish analyses. Optimization does not generate the standard-mode `05_dada2/table-summary.qzv`; inspect the selected table and stats when choosing diversity depth.

Keep raw reads, QIIME artifacts, container images, work directories, and participant metadata out of Git.

<a id="en-tests"></a>

### 9. Tests and releases

Run the bundled synthetic test without biological input data, metadata, or a classifier:

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile test,docker
```

Use `test,singularity` or `test,apptainer` for those runtimes. In a local checkout, also run the output verifier:

```bash
nextflow run . -profile test,singularity
python3 tests/check_containers.py results/primer-test
```

A successful run completes five tasks across four images:

| Task | Check |
|---|---|
| Cutadapt | Primer assertions and actual trimming; each mate must contain one 60-base T sequence |
| FastQC | Generate reports from the trimmed reads |
| MultiQC | Combine FastQC results into a report |
| QIIME import | Import paired reads and generate a demux summary |
| QIIME plugin check | Load required DADA2, feature-classifier, phylogeny, diversity, and taxa actions |

Reports are in `results/primer-test/container_qc/`, QIIME artifacts in `results/primer-test/04_qiime2_import/`, and the plugin log in `results/primer-test/container_checks/qiime-container.txt`.

Omit local image overrides to check public image retrieval. Set a new writable image-cache directory to test a cold cache. Rerun without `-resume` to execute tools again using cached images. Full DADA2, classification, phylogeny, diversity, and biological validity of the selected truncation pair are outside this test's coverage. See [tests/README.md](tests/README.md) for YAML/CLI precedence checks.

[GitHub Actions](.github/workflows/ci.yml) runs the Docker test and output verifier on pushes and pull requests. A `v*` tag publishes a GitHub release only after that tag's test passes. See [CHANGELOG.md](CHANGELOG.md) for release changes.

<a id="en-structure"></a>

### 10. Code structure

| Path | Purpose |
|---|---|
| [main.nf](main.nf) | Stage connections, branching, and input checks |
| [nextflow.config](nextflow.config) | Default parameters, containers, and runtime profiles |
| [nextflow_schema.json](nextflow_schema.json) | Parameter schema |
| [conf/base.config](conf/base.config) | Default task resources |
| [lib/PrimerConfig.groovy](lib/PrimerConfig.groovy) | Region primers and adapter resolution |
| [params/regions/](params/regions/) | Region preset YAML files |
| [params/examples/](params/examples/) | Custom primer YAML example |
| [params/trimming/](params/trimming/) | Default F/R candidate TSV files and design notes |
| [modules/](modules/) | Tool process commands |
| [subworkflows/qc.nf](subworkflows/qc.nf) | Shared raw/clean FastQC → MultiQC workflow |
| [subworkflows/trimm_optimal.nf](subworkflows/trimm_optimal.nf) | Candidate input, execution, ranking, and selection |
| [tests/](tests/) | Synthetic FASTQ, primer/container tests, output verifiers |

Individual tools are called from `main.nf`. QC and truncation optimization remain subworkflows because they connect multiple steps.

---

<a id="korean"></a>

## 한국어

### 목차

1. [빠른 실행](#ko-start)
2. [FASTQ와 샘플 정보](#ko-inputs)
3. [영역과 프라이머](#ko-primers)
4. [절단 길이 최적화](#ko-optimization)
5. [컨테이너와 캐시](#ko-containers)
6. [서버 자원 설정](#ko-resources)
7. [분석 설정과 코드 수정](#ko-options)
8. [결과 확인](#ko-outputs)
9. [테스트와 릴리스](#ko-tests)
10. [코드 구조](#ko-structure)

<a id="ko-start"></a>

### 1. 빠른 실행

Illumina paired-end 16S rRNA의 V1V3 또는 V3V4 영역을 분석하는 파이프라인입니다. DADA2의 forward/reverse 절단 길이를 비교해 완료된 후보 중 가장 높은 순위의 조합을 선택하고, 해당 ASV로 후속 분석을 진행할 수 있습니다.

**분석 흐름:** FASTQ → FastQC/MultiQC → Cutadapt → FastQC/MultiQC → QIIME 2 가져오기 → DADA2(고정 길이 또는 후보 비교) → 분류 → MAFFT/FastTree → 다양성 분석.

Linux, Java 17+, Nextflow 26.04.2 이상(검증 버전: 26.04.2)과 Docker·Singularity·Apptainer 중 하나를 준비합니다. 입력 데이터는 FASTQ, metadata TSV, QIIME 2 amplicon 2025.7과 호환되는 classifier QZA입니다. SILVA, GG2 등 호환되는 분류기를 사용할 수 있습니다.

저장소 밖에 `analysis.yml`을 작성합니다. 파일명은 `nextflow_params.yml`로 정해도 됩니다. 아래 경로를 실제 경로로 바꾸세요.

```yaml
region: V3V4
reads: "/path/to/reads/*_{1,2}.fastq.gz"
metadata: "/path/to/metadata.tsv"
classifier: "/path/to/classifier.qza"
outdir: "/path/to/results"
run_label: "experiment01"
trimm_optimal: true
taxonomy_label: SILVA
taxonomy_confidence: 0.7
diversity_enabled: true
sampling_depth: 1000
```

저장소를 복제하지 않고 GitHub에서 릴리스 버전을 바로 실행할 수 있습니다.

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile singularity \
  -params-file /path/to/analysis.yml \
  -work-dir /path/to/work
```

실행 환경에 따라 `-profile docker`, `-profile singularity`(기본 실행 환경), `-profile apptainer`를 선택합니다. 이미지는 첫 실행 때 내려받고 이후 캐시를 재사용합니다. 분석 도구를 서버에 각각 설치할 필요는 없습니다.

저장소를 로컬에 복제했다면 다음과 같이 실행합니다.

```bash
nextflow run /path/to/amplicon_16S_qiime_nf/main.nf \
  -profile singularity -params-file /path/to/analysis.yml \
  -work-dir /path/to/work
```

V1V3 데이터는 `region: V1V3`로 설정합니다. 영역별 기본 후보를 사용하려면 `trimm_combinations`를 생략합니다. 위 예시는 최적화를 켠 설정이며, 코드의 `trimm_optimal` 기본값은 `false`입니다.

다양성 분석을 생략하려면 `diversity_enabled: false`로 설정합니다. `sampling_depth`는 샘플별 read 수에 맞게 조정하세요. 분석을 재개할 때는 같은 실행 폴더와 작업 폴더를 유지하고 `-resume`을 추가합니다. 입력·옵션·모듈 구조가 바뀌면 해당 작업이 다시 실행될 수 있습니다. 최신 개발 코드는 `-r v0.1.0` 대신 `-r main -latest`로 실행합니다.

<a id="ko-inputs"></a>

### 2. FASTQ와 샘플 정보

`reads`의 파일명 패턴으로 read 쌍을 묶고, `metadata`로 샘플 정보를 읽습니다. **FASTQ 경로를 나열한 CSV samplesheet(`--input`, `--samplesheet`)는 지원하지 않습니다.** QIIME 2 가져오기에 쓰는 manifest는 Cutadapt 처리 후 자동 생성합니다.

샘플마다 R1/R2 한 쌍을 준비합니다.

```text
reads/
  S01_1.fastq.gz
  S01_2.fastq.gz
  S02_1.fastq.gz
  S02_2.fastq.gz
```

위 파일은 `reads: "/path/to/reads/*_{1,2}.fastq.gz"`로 지정합니다. 추출되는 샘플 ID는 `S01`, `S02`입니다. 파일명이 `_R1_001.fastq.gz`, `_R2_001.fastq.gz`로 끝나면 `*_{R1,R2}_001.fastq.gz` 패턴을 사용하세요.

첫 열이 `sample-id`인 탭 구분 샘플 정보 파일을 준비합니다.

```tsv
sample-id	group
S01	control
S02	treatment
```

터미널에서 실제 탭 문자가 들어간 예제 파일을 만들려면 다음 명령을 사용합니다.

```bash
printf 'sample-id\tgroup\nS01\tcontrol\nS02\ttreatment\n' > metadata.tsv
```

분석 YAML의 `metadata`에 파일의 절대 경로를 지정합니다. 샘플 ID는 중복 없이 파일명에서 추출한 ID와 정확히 일치해야 합니다. `group`은 예시이므로 실험 조건·배치 등의 열로 바꾸거나 확장하세요. 열 구분자는 쉼표나 공백이 아닌 탭입니다. V1V3와 V3V4는 각 영역에 해당하는 reads와 metadata로 나누어 실행합니다.

<a id="ko-primers"></a>

### 3. 영역과 프라이머

기본 영역은 V1V3입니다.

| 영역 | Forward 프라이머 (5′→3′) | Reverse 프라이머 (5′→3′) |
|---|---|---|
| V1V3 | `AGAGTTTGATCCTGGCTCAG` | `ATTACCGCGGCTGCTGG` |
| V3V4 | `CCTACGGGNGGCWGCAG` | `GACTACHVGGGTATCTAATCC` |

`--region V3V4`로 선택하거나 [params/regions](params/regions)의 YAML을 사용합니다. 직접 지정하려면 실행 명령에 다음 옵션을 추가하세요.

```bash
--region V3V4 --primer_f 'CCTACGGGNGGCWGCAG' --primer_r 'GACTACHVGGGTATCTAATCC'
```

**적용 우선순위: 명령줄 > 외부 파라미터 YAML > 영역 기본값.** 한쪽 프라이머만 지정하면 나머지는 해당 영역의 기본값을 사용합니다. YAML 예시는 [custom_primers.yml](params/examples/custom_primers.yml)을 참고하세요.

프라이머는 소문자를 포함한 IUPAC DNA 문자를 허용합니다. Read-through adapter는 반대쪽 프라이머의 역상보 서열로 계산하며, `adapter_f` 또는 `adapter_r`를 직접 지정하면 그 값을 사용합니다. V1V3 기본 프라이머의 adapter는 `CCAGCAGCCGCGGTAAT`, `CTGAGCCAGGATCAAACTCT`입니다. 최종 서열은 실행 로그에 표시합니다.

<a id="ko-optimization"></a>

### 4. 절단 길이 최적화

`trimm_optimal: true`로 후보 비교를 활성화합니다. 절단 길이는 Cutadapt 처리 후 QIIME 2로 가져온 reads에 적용합니다.

1. 후보 TSV의 forward/reverse 조합마다 DADA2를 독립 실행합니다.
2. 후보별 ASV를 분류하고 read 유지율과 species 분류 지표를 계산합니다.
3. 완료된 후보를 아래 기준으로 내림차순 정렬합니다. 앞 기준이 같으면 다음 기준으로 비교합니다.
4. 최상위 후보의 feature table과 대표 서열로 분류·계통수·다양성 분석을 진행합니다.

| 우선순위 | 지표 | 계산 |
|---|---|---|
| 1 | `species_input_yield` | Species로 분류된 reads / DADA2 입력 reads × 100 |
| 2 | `species_read_pct` | Species로 분류된 reads / 최종 feature table reads × 100 |
| 3 | `nonchimeric_pct` | Non-chimeric reads / DADA2 입력 reads × 100 |

여기서 “최적”은 지정한 분류기와 순위 기준에 따라 제공된 후보 중 가장 높은 순위라는 뜻입니다. 보편적인 생물학적 최적값을 보장하지 않습니다. 샘플별 순위가 아닌 전체 데이터의 합산 지표를 사용합니다. Species 판정에는 taxonomy의 `s__` 또는 `s:` 표기를 사용하며 unknown, uncultured 등의 이름은 제외합니다.

영역에 따라 [v1v3_10bp.tsv](params/trimming/v1v3_10bp.tsv)의 6개 후보 또는 [v3v4_10bp.tsv](params/trimming/v3v4_10bp.tsv)의 10개 후보를 사용합니다. 다른 후보를 쓰려면 `trimm_combinations: "/path/to/candidates.tsv"` 또는 `--trimm_combinations /path/to/candidates.tsv`로 지정합니다.

```tsv
name	trunc_len_f	trunc_len_r
F280_R270	280	270
F280_R260	280	260
F270_R250	270	250
```

열은 실제 탭으로 구분하고 후보 이름은 고유하게 지정합니다. 현재 코드는 **F > R**, 두 길이 모두 **10 nt 단위**인지 확인합니다. 기본 후보의 설계 기준은 V1V3에서 F + R − 20 ≥ 500 bp, V3V4에서 ≥ 460 bp입니다. 일반·최적화 DADA2 모두 최소 overlap은 12 bp입니다. 이 설계 기준이 검증된 생물학적 최대 길이를 뜻하지는 않으므로 실제 read 길이와 품질에 맞춰 조정하세요. 출처·길이 가정·overlap 계산은 [후보 설계 설명](params/trimming/README.md)에 정리되어 있습니다.

DADA2 또는 분류 작업이 실패한 후보는 비교에서 제외합니다. 성공한 후보가 없으면 선택 단계가 실패합니다. `optimal_min_sample_reads` 기본값은 10000이며, 기준보다 read가 적은 샘플 수와 merge가 0인 샘플 수는 보고용입니다. 후보 제외나 순위 계산에는 사용하지 않습니다.

고정 길이로 분석하려면 `trimm_optimal: false`와 `dada2_trunc_len_f`, `dada2_trunc_len_r`를 사용합니다. 두 길이의 기본값 `0`은 고정 길이 절단을 하지 않는다는 뜻입니다. 최적화 모드에서는 이 두 파라미터 대신 TSV의 길이를 사용합니다.

<a id="ko-containers"></a>

### 5. 컨테이너와 캐시

도구별 로컬 경로를 지정하지 않으면 아래 버전의 공개 이미지를 사용합니다.

| 도구 | 공개 이미지 | 로컬 SIF/IMG 파라미터 |
|---|---|---|
| FastQC | `quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0` | `fastqc_sif` |
| MultiQC | `quay.io/biocontainers/multiqc:1.27--pyhdfd78af_0` | `multiqc_sif` |
| Cutadapt | `quay.io/biocontainers/cutadapt:5.2--py311hc303176_2` | `cutadapt_sif` |
| QIIME 2 | `quay.io/qiime2/amplicon:2025.7` | `qiime_sif` |

FastQC와 MultiQC는 이미지와 설정을 각각 따로 사용합니다. 통합 QC 이미지와 공통 경로 설정은 더 이상 사용하지 않습니다. QIIME 2 분석 단계는 하나의 QIIME 2 이미지를 공유합니다.

보유한 이미지를 사용하려면 필요한 항목을 `analysis.yml` 또는 `nextflow_params.yml`에 추가합니다.

```yaml
fastqc_sif: "/absolute/path/to/fastqc.sif"
multiqc_sif: "/absolute/path/to/multiqc.img"
cutadapt_sif: "/absolute/path/to/cutadapt.sif"
qiime_sif: "/absolute/path/to/qiime2.sif"
```

로컬 SIF/IMG 파일은 `-profile singularity` 또는 `-profile apptainer`로 실행합니다. 해당 실행 환경에서 읽을 수 있는 이미지여야 하며, Docker는 이 파일을 사용할 수 없습니다. 경로를 생략한 도구는 공개 이미지를 자동으로 내려받습니다. 로컬 경로를 지정하면 해당 도구에만 우선 적용합니다.

첫 실행에는 이미지 저장소 접속과 충분한 디스크 공간이 필요합니다. 특히 QIIME 2 이미지의 용량을 고려하세요. Singularity/Apptainer 이미지 주소에는 `docker://`를 붙이고 Docker에서는 생략합니다. 자세한 내용은 [Nextflow 컨테이너 문서](https://docs.seqera.io/nextflow/container/singularity)를 참고하세요.

실행 전에 Singularity 이미지 캐시 경로를 지정하면 여러 분석에서 재사용할 수 있습니다.

```bash
export NXF_SINGULARITY_CACHEDIR=/path/to/container-cache
mkdir -p "$NXF_SINGULARITY_CACHEDIR"
```

Apptainer는 `NXF_APPTAINER_CACHEDIR`를 사용합니다. Docker의 이미지 저장 공간은 Docker가 관리합니다. HPC에서는 모든 계산 노드가 접근할 수 있고 쓰기 가능한 캐시를 사용하세요. 이미지 캐시는 재다운로드를 줄이는 기능이며, 완료된 분석 결과를 재사용하는 `-resume`과는 별개입니다.

**현재 연구실 서버 설정.** 기존 분석 YAML에 아래 QC 경로를 넣습니다. reads·metadata·classifier 등 나머지 분석 설정은 함께 유지합니다.

```yaml
fastqc_sif: "/data/software/singularity/quay.io-biocontainers-fastqc-0.12.1--hdfd78af_0.img"
multiqc_sif: "/data/software/singularity/quay.io-biocontainers-multiqc-1.27--pyhdfd78af_0.img"
```

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile singularity -params-file /path/to/nextflow_params.yml
```

이 서버에는 동일한 QC 경로를 담은 `/data/software/singularity/amplicon_16S_qc.config`도 있습니다. 다음 명령으로 테스트할 수 있습니다.

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile test,singularity \
  -c /data/software/singularity/amplicon_16S_qc.config
```

위 절대 경로와 config 파일은 해당 서버 전용입니다. 외부 사용자는 자신의 로컬 경로를 지정하거나 경로 설정을 생략해 자동 다운로드를 사용하세요.

<a id="ko-resources"></a>

### 6. 서버 자원 설정

데이터 경로와 분석 파라미터는 외부 YAML에 둡니다. 실행 방식·queue·CPU·메모리·시간 제한은 외부 `site.config`로 설정합니다. [nextflow.config](nextflow.config)의 기본 실행 방식은 `local`입니다.

[conf/base.config](conf/base.config)에 정의된 작업 하나당 기본 자원은 다음과 같습니다.

| 라벨 | CPU 수 | 메모리 | 시간 |
|---|---|---|---|
| `process_low` | 8 | 16 GB | 12 h |
| `process_medium` | 8 | 24 GB | 24 h |
| `process_high` | 16 | 64 GB | 72 h |

최적화 후보는 동시에 실행될 수 있으므로 서버와 데이터 크기에 맞춰 자원을 조정하세요. 다음은 `site.config` 예시입니다.

```groovy
process {
    executor = 'local'
    maxForks = 1
    withLabel: process_low {
        cpus = 2
        memory = '4 GB'
    }
    withLabel: process_medium {
        cpus = 4
        memory = '8 GB'
    }
    withLabel: process_high {
        cpus = 8
        memory = '32 GB'
    }
}
```

실행 명령에 `-c /path/to/site.config`를 추가합니다. 위 수치는 문법 예시이며 모든 데이터에 적합한 값은 아닙니다. `maxForks`는 프로세스별 동시 작업 수를 제한하며, 전체 프로세스를 합친 동시 작업 수 제한은 아닙니다. HPC의 스케줄러와 queue는 기관 환경에 맞춰 지정합니다. 작업 폴더는 `-work-dir`로 설정합니다.

<a id="ko-options"></a>

### 7. 분석 설정과 코드 수정

먼저 파라미터로 조정하고, 명령이나 로직을 바꿔야 할 때 도구 모듈을 수정합니다.

| 변경 목적 | 파라미터 또는 기본값 | 구현 위치 |
|---|---|---|
| FastQC / MultiQC | 개별 이미지 경로와 CPU 설정 | [fastqc.nf](modules/fastqc.nf), [multiqc.nf](modules/multiqc.nf) |
| 영역·프라이머·adapter | `region`, `primer_f`, `primer_r`, `adapter_f`, `adapter_r` | [PrimerConfig.groovy](lib/PrimerConfig.groovy) |
| Cutadapt 필터 | `quality: 20`, `min_length: 50` | [cutadapt.nf](modules/cutadapt.nf); `-n 2`, `--discard-untrimmed` 등 |
| QIIME 가져오기 | `reads` 파일명 패턴 | [qiime_import.nf](modules/qiime_import.nf) |
| 고정 길이 DADA2 | `dada2_trunc_len_f: 0`, `dada2_trunc_len_r: 0`, `dada2_max_ee_f: 2`, `dada2_max_ee_r: 4` | [qiime_dada2.nf](modules/qiime_dada2.nf) |
| 후보 조건 검사 | `trimm_optimal`, `trimm_combinations` | [subworkflows/trimm_optimal.nf](subworkflows/trimm_optimal.nf), [params/trimming](params/trimming) |
| 후보 실행 | 동일한 `dada2_max_ee_*` 설정 | [modules/trimm_optimal.nf](modules/trimm_optimal.nf)의 `DADA2_TRIMM_SWEEP` |
| 순위·species 판정 | `optimal_min_sample_reads: 10000`은 보고 기준만 변경 | 같은 모듈의 `TAXONOMY_TRIMM_SWEEP`, `SELECT_TRIMM_OPTIMAL` |
| 분류 | `classifier`, `taxonomy_confidence: 0.7`, `taxonomy_label: AUTO` | [qiime_taxonomy.nf](modules/qiime_taxonomy.nf)와 `modules/trimm_optimal.nf`의 후보 분류 |
| MAFFT / FastTree | 별도 분석 파라미터 없음 | [qiime_phylogeny.nf](modules/qiime_phylogeny.nf) |
| 다양성·rarefaction | `diversity_enabled: true`, `sampling_depth: 1000`, `alpha_max_depth: 10000` | [qiime_diversity.nf](modules/qiime_diversity.nf) |

DADA2의 `trunc-q`나 chimera 처리처럼 명령에 고정된 옵션은 일반 모듈과 최적화 모듈을 모두 확인합니다. 후보 분류와 최종 분류 명령도 일관되게 유지하세요. 파라미터를 추가하면 [nextflow.config](nextflow.config), [nextflow_schema.json](nextflow_schema.json), 해당 모듈, README의 두 언어 설명을 함께 갱신합니다.

이미지 버전을 바꿀 때는 명령 옵션과 분류기 호환성을 확인합니다. 최종 분석에 사용한 이미지 버전과 분류기는 함께 기록하세요.

<a id="ko-outputs"></a>

### 8. 결과 확인

모든 결과는 `outdir` 아래에 저장합니다.

| 폴더 | 내용 |
|---|---|
| `01_raw_qc/`, `03_clean_qc/` | 필터링 전·후 FastQC/MultiQC |
| `02_cutadapt_q20/` | 처리된 FASTQ, Cutadapt 로그·JSON. `quality`를 바꿔도 폴더명은 고정 |
| `04_qiime2_import/` | Manifest, paired-end QZA, 품질 요약 |
| `05_dada2/` | 최적화를 끈 일반 DADA2 결과와 요약 |
| `05_trimm_optimal_dada2/` | 후보별 DADA2 결과 |
| `05_trimm_optimal_<LABEL>/` | 후보별 분류 결과와 지표 |
| `05_trimm_optimal_<LABEL>/selected/` | 전체 순위, 선택 길이, 선택된 QZA |
| `06_taxonomy/` | `taxonomy_<LABEL>.qza`, `taxa-bar-plots_<LABEL>.qzv` 등 |
| `07_phylogeny/`, `08_diversity/` | 계통수와 활성화한 경우 다양성 결과 |

최적화 후에는 다음 파일을 먼저 확인합니다.

- `all_parameter_results.tsv`: 성공한 후보의 순위와 평가 지표.
- `optimal_selection.tsv`, `optimal_truncation.txt`: 선택된 F/R 길이와 점수.
- `selected-table.qza`, `selected-rep-seqs.qza`, `selected-denoising-stats.qza`: 후속 분석에 전달한 산출물.

`taxonomy_label: AUTO`는 classifier 경로에서 SILVA·GG2·GTDB 등의 라벨을 추론합니다. 분석을 구분하려면 라벨을 직접 지정하세요. 최적화 모드에서는 일반 모드의 `05_dada2/table-summary.qzv`를 생성하지 않습니다. 다양성 분석 깊이는 선택된 table과 stats를 확인해 정합니다.

원시 reads, QIIME 산출물, 컨테이너 이미지, 작업 폴더, 참여자 정보는 Git에 올리지 않습니다.

<a id="ko-tests"></a>

### 9. 테스트와 릴리스

실제 연구 데이터·샘플 정보·분류기 없이 제공된 합성 데이터로 테스트할 수 있습니다.

```bash
nextflow run KitHubb/amplicon_16S_qiime_nf -r v0.1.0 \
  -profile test,docker
```

실행 환경에 따라 `test,singularity` 또는 `test,apptainer`로 바꿉니다. 로컬에 저장소가 있다면 결과 검증도 실행하세요.

```bash
nextflow run . -profile test,singularity
python3 tests/check_containers.py results/primer-test
```

정상 실행 시 이미지 4종으로 다음 작업 5개를 완료합니다.

| 작업 | 확인 내용 |
|---|---|
| Cutadapt | 프라이머 조건 검사와 실제 절단. 각 mate에 60개의 T로 된 서열 한 개가 남는지 확인 |
| FastQC | 처리된 reads의 보고서 생성 |
| MultiQC | FastQC 결과를 통합한 보고서 생성 |
| QIIME 가져오기 | Paired reads를 가져오고 demux 요약 생성 |
| QIIME 플러그인 검사 | 필요한 DADA2·feature-classifier·phylogeny·diversity·taxa 명령 로딩 |

보고서는 `results/primer-test/container_qc/`, QIIME 산출물은 `results/primer-test/04_qiime2_import/`, 플러그인 로그는 `results/primer-test/container_checks/qiime-container.txt`에 저장합니다.

공개 이미지 다운로드를 확인하려면 로컬 이미지 경로를 생략합니다. 빈 캐시에서 확인하려면 새로 만든 쓰기 가능한 이미지 캐시 폴더를 지정하세요. 캐시된 이미지로 도구를 다시 실행하려면 `-resume` 없이 재실행합니다. 전체 DADA2·분류·계통수·다양성 분석과 선택 길이의 생물학적 타당성은 이 테스트의 검증 범위가 아닙니다. YAML과 명령줄의 우선순위 검사는 [tests/README.md](tests/README.md)를 참고하세요.

[GitHub Actions](.github/workflows/ci.yml)는 push와 pull request마다 Docker 테스트와 결과 검증을 실행합니다. `v*` 태그의 테스트가 통과하면 GitHub 릴리스를 게시합니다. 버전별 변경은 [CHANGELOG.md](CHANGELOG.md)에서 확인할 수 있습니다.

<a id="ko-structure"></a>

### 10. 코드 구조

| 경로 | 역할 |
|---|---|
| [main.nf](main.nf) | 단계 연결·분기·입력 확인 |
| [nextflow.config](nextflow.config) | 기본 파라미터·컨테이너·실행 프로필 |
| [nextflow_schema.json](nextflow_schema.json) | 파라미터 명세 |
| [conf/base.config](conf/base.config) | 작업 자원 기본값 |
| [lib/PrimerConfig.groovy](lib/PrimerConfig.groovy) | 영역별 프라이머와 adapter 해석 |
| [params/regions/](params/regions/) | 영역 선택용 YAML |
| [params/examples/](params/examples/) | 사용자 프라이머 YAML 예시 |
| [params/trimming/](params/trimming/) | 기본 F/R 후보 TSV와 설계 설명 |
| [modules/](modules/) | 도구별 실행 명령 |
| [subworkflows/qc.nf](subworkflows/qc.nf) | 처리 전·후 공통 FastQC → MultiQC 흐름 |
| [subworkflows/trimm_optimal.nf](subworkflows/trimm_optimal.nf) | 후보 입력·실행·순위·선택 연결 |
| [tests/](tests/) | 합성 FASTQ·프라이머/컨테이너 테스트·결과 검증 |

개별 도구는 `main.nf`에서 호출합니다. 여러 단계를 연결하는 QC와 절단 길이 최적화는 subworkflow로 구성합니다.

---
