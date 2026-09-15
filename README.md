# amplicon_16S_qiime_nf

An Illumina paired-end 16S rRNA pipeline for V1V3 and V3V4. It compares forward/reverse DADA2 truncation pairs and selects the best completed pair using taxonomy and read-retention metrics.

Workflow: FASTQ → FastQC/MultiQC → Cutadapt → FastQC/MultiQC → QIIME 2 import → DADA2 truncation sweep and selection → taxonomy → MAFFT/FastTree → diversity analysis.

## 1. Quick start

Install Nextflow (tested with 26.04.2), Java 17+, and Docker, Singularity, or Apptainer. Public images are downloaded on first use and cached; no manual image build is needed. Choose `-profile docker`, `-profile singularity` (the default runtime), or `-profile apptainer`.

Create an external `analysis.yml` so project paths remain outside the repository:

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

```bash
nextflow run /path/to/amplicon_16S_qiime_nf/main.nf \
  -profile singularity -params-file /path/to/analysis.yml \
  -work-dir /path/to/work -resume
```

Metadata must be tab-delimited, start with `sample-id`, and match FASTQ sample IDs.

## 2. Forward/reverse truncation optimization

Set `trimm_optimal: true`. Each candidate F/R pair is run independently with DADA2 after Cutadapt. Candidate ASVs are classified, then completed candidates are ranked by species-assigned reads per DADA2 input read, species-assigned reads per feature-table read, and non-chimeric reads per input read. The top candidate is sent to downstream taxonomy, phylogeny, and diversity analysis.

“Optimal” means best among the supplied candidates and classifier, not a universal biological optimum. Ranking uses aggregate reads across the dataset.

Region defaults are selected automatically:

- `--region V1V3` → [v1v3_10bp.tsv](params/trimming/v1v3_10bp.tsv)
- `--region V3V4` → [v3v4_10bp.tsv](params/trimming/v3v4_10bp.tsv)

An external `--trimm_combinations` TSV overrides the region default. It must contain `name`, `trunc_len_f`, and `trunc_len_r`; current validation requires F > R and 10-nt increments. The candidate design requires F+R-20 >= 500 bp for V1V3 and >= 460 bp for V3V4 (DADA2 merge minimum: 12 bp). These design bounds are not verified biological maxima. V1V3 contains 6 candidates and V3V4 contains 10 candidates. Calculations and sources are documented in [params/trimming/README.md](params/trimming/README.md).

## 3. Region and primer selection

| Region | Forward primer (5′→3′) | Reverse primer (5′→3′) |
|---|---|---|
| V1V3 | AGAGTTTGATCCTGGCTCAG | ATTACCGCGGCTGCTGG |
| V3V4 | CCTACGGGNGGCWGCAG | GACTACHVGGGTATCTAATCC |

Use `--region V3V4`, a preset in [params/regions](params/regions), or `--primer_f` / `--primer_r` overrides. Priority is command line > external YAML > region defaults. IUPAC letters are validated and lowercase is accepted. Adapters are reverse complements of the opposite primer unless explicitly supplied.

## 4. Adapting to a research environment

Usually an external YAML is sufficient.

| Purpose | File or parameter |
|---|---|
| Container paths | `qc_sif`, `cutadapt_sif`, `qiime_sif` in [nextflow.config](nextflow.config) or YAML |
| CPU, memory, time, executor | [conf/base.config](conf/base.config), [nextflow.config](nextflow.config), external site config |
| Region and primer defaults | [lib/PrimerConfig.groovy](lib/PrimerConfig.groovy) |
| Cutadapt filters | `quality`, `min_length`, [modules/cutadapt.nf](modules/cutadapt.nf) |
| Fixed DADA2 settings | `dada2_trunc_len_*`, `dada2_max_ee_*`, [modules/qiime_dada2.nf](modules/qiime_dada2.nf) |
| Candidate execution and ranking | [params/trimming](params/trimming), [subworkflows/trimm_optimal.nf](subworkflows/trimm_optimal.nf), [modules/trimm_optimal.nf](modules/trimm_optimal.nf) |
| Taxonomy | `classifier`, `taxonomy_confidence`, [modules/qiime_taxonomy.nf](modules/qiime_taxonomy.nf) |
| Phylogeny | [modules/qiime_phylogeny.nf](modules/qiime_phylogeny.nf) |
| Diversity | `diversity_enabled`, `sampling_depth`, `alpha_max_depth`, [modules/qiime_diversity.nf](modules/qiime_diversity.nf) |

If a command option is hard-coded, update both regular and optimization modules where applicable. Add new parameters to `nextflow.config`, [nextflow_schema.json](nextflow_schema.json), the relevant module, and both language sections of this README.

## 5. Outputs

Results are written below `outdir`: `01_raw_qc`, `02_cutadapt_q20`, `03_clean_qc`, `04_qiime2_import`, `05_dada2`, `06_taxonomy`, `07_phylogeny`, and `08_diversity`. Optimization additionally writes `05_trimm_optimal_dada2/` and `05_trimm_optimal_<LABEL>/selected/`. Review `all_parameter_results.tsv`, `optimal_selection.tsv`, and `optimal_truncation.txt` first.

Do not commit raw reads, QIIME artifacts, containers, work directories, or participant metadata. Synthetic primer tests are documented in [tests/README.md](tests/README.md).

---

Illumina paired-end 16S V1V3/V3V4 분석 파이프라인입니다. 핵심 기능은 **forward와 reverse read의 DADA2 절단 길이 조합을 비교하고, 지정한 평가 기준에 따라 최적 조합을 선택**하는 것입니다. 선택된 ASV 결과로 taxonomy, 계통수 및 다양성 분석을 이어갑니다.

분석 흐름: FASTQ → FastQC/MultiQC → Cutadapt → FastQC/MultiQC → QIIME 2 import → DADA2 절단 길이 비교·선택 → taxonomy → MAFFT/FastTree → 다양성 분석.

## 1. 빠른 실행

필요 환경은 Linux, Java 17+, Nextflow 26.04.2(검증 버전), Docker 또는 Singularity/Apptainer입니다. 컨테이너 이미지는 첫 실행 시 자동 다운로드하고 이후 캐시를 재사용합니다. FASTQ, QIIME 2 metadata TSV, classifier QZA는 연구자가 준비합니다. 실행 프로필은 `docker`, `singularity`(기본), `apptainer` 중 하나를 선택합니다.

프로젝트 폴더에 `analysis.yml`을 작성합니다. 실제 데이터 경로와 설정은 저장소 밖에서 관리할 수 있습니다.

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

```bash
nextflow run /path/to/amplicon_16S_qiime_nf/main.nf \
  -profile singularity \
  -params-file /path/to/analysis.yml \
  -work-dir /path/to/work \
  -resume
```

- `Sample01_1.fastq.gz` / `Sample01_2.fastq.gz`는 위 패턴으로 입력합니다. `_R1_001` / `_R2_001` 형식은 `*_{R1,R2}_001.fastq.gz`로 바꿉니다.
- Metadata는 탭으로 구분하고 첫 열을 `sample-id`로 지정합니다. ID는 FASTQ 패턴에서 추출한 ID와 일치해야 합니다.
- Classifier는 사용하는 QIIME 2 환경과 호환되는 artifact를 지정합니다. SILVA 이외의 classifier도 지정할 수 있습니다.
- 다양성 분석을 생략하려면 `diversity_enabled: false`로 설정합니다. `sampling_depth: 1000`은 기본값이며 연구 데이터의 read 수에 맞게 조정합니다.
- 재실행 시 같은 work 경로와 `-resume`을 사용합니다. 모듈 호출 구조·옵션·입력이 바뀌면 해당 작업이 다시 실행될 수 있습니다.

## 2. Forward/Reverse 절단 길이 최적화

`trimm_optimal: true`일 때 활성화됩니다. **코드 기본값은 false**이며, 위 실행 예시는 최적화를 명시적으로 켭니다.

1. 후보 TSV의 각 F/R 조합으로 DADA2를 독립 실행합니다. 절단 길이는 Cutadapt 처리 후 QIIME 2에 입력된 reads에 적용됩니다.
2. 각 후보의 ASV를 지정한 classifier로 분류하고 read 유지율 및 species 분류 지표를 계산합니다.
3. 완료된 후보를 아래 기준으로 내림차순 정렬합니다. 앞 기준이 같을 때 다음 기준을 사용합니다.
4. 최상위 후보의 table과 대표 서열을 최종 taxonomy·계통수·다양성 분석에 전달합니다.

| 순위 기준 | 계산 |
|---|---|
| 1. `species_input_yield` | species 분류 reads / DADA2 입력 reads × 100 |
| 2. `species_read_pct` | species 분류 reads / 최종 feature table reads × 100 |
| 3. `nonchimeric_pct` | non-chimeric reads / DADA2 입력 reads × 100 |

여기서 “optimal”은 **제공된 후보와 classifier, 현재 순위 기준 안에서 최상위인 조합**입니다. 모든 길이를 탐색하거나 생물학적 정확도를 보장하는 의미는 아닙니다. 선택은 샘플별이 아닌 입력 데이터 전체의 합산 지표를 기준으로 합니다. Species 판정은 taxonomy 문자열의 `s__` 또는 `s:` 표기를 사용하고 unknown·uncultured 등의 이름을 제외합니다.

### 후보 길이 변경

영역별 기본 파일은 [v1v3_10bp.tsv](params/trimming/v1v3_10bp.tsv)와 [v3v4_10bp.tsv](params/trimming/v3v4_10bp.tsv)이며, 각각 6개와 10개 조합이 들어 있습니다. `--region`에 따라 자동 선택하고, 외부 TSV를 `--trimm_combinations /path/to/candidates.tsv` 또는 YAML의 `trimm_combinations`로 지정하면 우선합니다. 문헌 출처, primer 제거 후 길이 가정과 후보별 overlap 계산은 [trimming 설명](params/trimming/README.md)을 참고하세요.

```tsv
name	trunc_len_f	trunc_len_r
F280_R270	280	270
F280_R260	280	260
F270_R250	270	250
```

- 실제 파일은 탭으로 구분하고 후보 이름은 고유하게 지정합니다.
- 현재 구현은 **F > R**, 두 길이 모두 **10 nt 단위**라는 조건을 검사합니다. 이 제한은 [subworkflows/trimm_optimal.nf](subworkflows/trimm_optimal.nf)에서 변경합니다.
- 기본 후보는 영역에 따라 자동 변경됩니다. 설계 하한은 F+R−20 ≥ 500 bp (V1V3), ≥ 460 bp (V3V4)이며, 일반·최적화 DADA2 모두 최소 overlap 12 bp를 사용합니다. 실제 길이와 품질에 맞춰 후보를 조정하세요.
- DADA2 또는 후보 taxonomy가 실패하면 해당 후보는 비교에서 빠집니다. 성공한 후보가 하나도 없으면 선택 단계가 실패합니다.
- `optimal_min_sample_reads` 기본값은 10000입니다. 이보다 낮은 샘플 수와 merge가 0인 샘플 수는 **보고용 지표**이며 후보 제외나 순위 계산에는 사용하지 않습니다.

고정 길이 분석은 `trimm_optimal: false`와 `dada2_trunc_len_f`, `dada2_trunc_len_r`로 실행합니다. 두 길이의 기본값 0은 고정 절단을 하지 않는 설정입니다. 최적화 모드에서는 이 두 옵션 대신 후보 TSV의 길이를 사용합니다.

## 3. 영역 및 primer 설정

| 영역 | Forward primer (5′→3′) | Reverse primer (5′→3′) |
|---|---|---|
| V1V3 — 기본값 | AGAGTTTGATCCTGGCTCAG | ATTACCGCGGCTGCTGG |
| V3V4 | CCTACGGGNGGCWGCAG | GACTACHVGGGTATCTAATCC |

`--region V3V4`로 선택하거나 [params/regions/](params/regions/)의 YAML을 `-params-file`로 지정합니다. 직접 지정은 다음과 같습니다.

```bash
# 위 실행 명령에 필요한 옵션만 추가
--region V3V4 --primer_f 'CCTACGGGNGGCWGCAG' --primer_r 'GACTACHVGGGTATCTAATCC'
```

우선순위는 **명령줄 > 외부 params YAML > 영역 기본값**입니다. 한쪽 primer만 지정하면 나머지는 해당 영역 기본값을 유지합니다. YAML 예시는 [params/examples/custom_primers.yml](params/examples/custom_primers.yml)을 참고합니다.

Primer는 IUPAC DNA 문자로 검사하고 소문자도 허용합니다. Read-through adapter는 반대쪽 primer의 역상보로 계산하며 `adapter_f`, `adapter_r`를 직접 지정하면 해당 값이 우선합니다. V1V3 기본 primer 사용 시 기존 adapter `CCAGCAGCCGCGGTAAT` / `CTGAGCCAGGATCAAACTCT`를 보존합니다. 최종 서열은 실행 로그에 표시됩니다.

## 4. 연구자 환경에 맞춰 수정할 파일

보통 **외부 `analysis.yml`에 경로와 분석 파라미터를 지정**하면 됩니다. 서버 실행 방식·CPU·메모리는 외부 `site.config`로 덮어쓸 수 있습니다. 저장소 전체의 기본 동작을 바꾸려면 아래 파일을 수정합니다.

### 컨테이너와 서버 자원

| 변경 내용 | 설정 또는 파일 | 설명 |
|---|---|---|
| FastQC·MultiQC 환경 | `qc_sif` — [nextflow.config](nextflow.config) 또는 외부 YAML | 선택 사항: 두 도구가 들어 있는 로컬 SIF 절대 경로. 미지정 시 각 BioContainers 이미지 사용 |
| Cutadapt 환경 | `cutadapt_sif` — 같은 위치 | 선택 사항: 로컬 SIF 절대 경로. 미지정 시 BioContainers Cutadapt 5.2 사용 |
| QIIME 2 환경 | `qiime_sif` — 같은 위치 | 선택 사항: 로컬 SIF 절대 경로. 미지정 시 공식 QIIME 2 amplicon 2025.7 이미지 사용 |
| 기본 CPU·메모리·시간 | [conf/base.config](conf/base.config) | `process_low`: 8 CPU/16 GB/12 h, `process_medium`: 8 CPU/24 GB/24 h, `process_high`: 16 CPU/64 GB/72 h |
| 로컬/HPC 실행 방식 | [nextflow.config](nextflow.config)의 `process.executor` | 현재 `local`. 스케줄러·queue 설정은 기관 환경에 맞춰 변경 |
| 컨테이너 실행 설정 | 같은 파일의 `singularity`, `profiles` | Docker, Singularity, Apptainer 선택; `test`와 조합 가능 |
| 입력·결과·classifier 경로 | 외부 YAML | `reads`, `metadata`, `classifier`, `outdir`; 작업 경로는 CLI `-work-dir` |

자원은 작업 하나당 설정입니다. 최적화 후보가 동시에 실행되므로 서버 전체 자원을 고려해야 합니다. 예를 들어 외부 `site.config`에 다음처럼 작성할 수 있습니다.

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

실행 명령에 `-c /path/to/site.config`를 추가합니다. 위 값은 형식 예시이며 데이터 크기에 맞춰 조정해야 합니다. `maxForks`는 프로세스별 동시 작업 수 제한이므로 모든 프로세스를 합친 전체 동시 작업 수 제한은 아닙니다.

### 분석 옵션과 도구 명령

| 변경 목적 | 먼저 사용할 파라미터 | 명령 또는 로직을 직접 바꿀 파일 |
|---|---|---|
| FastQC·MultiQC 옵션 | 컨테이너 및 CPU 설정 | [modules/fastqc.nf](modules/fastqc.nf), [modules/multiqc.nf](modules/multiqc.nf) |
| Primer·영역 | `region`, `primer_f/r`, `adapter_f/r` | 기본 서열·역상보·검사: [lib/PrimerConfig.groovy](lib/PrimerConfig.groovy) |
| Cutadapt 품질 필터 | `quality: 20`, `min_length: 50` | [modules/cutadapt.nf](modules/cutadapt.nf): `-n 2`, `--discard-untrimmed` 등 |
| QIIME import 방식 | `reads` 입력 패턴 | [modules/qiime_import.nf](modules/qiime_import.nf) |
| DADA2 고정 길이·오류 허용 | `dada2_trunc_len_f/r: 0`, `dada2_max_ee_f: 2`, `dada2_max_ee_r: 4` | 일반 분석: [modules/qiime_dada2.nf](modules/qiime_dada2.nf) |
| DADA2 최적화 후보 실행 | `trimm_optimal`, `trimm_combinations`, 동일한 `dada2_max_ee_*` | [modules/trimm_optimal.nf](modules/trimm_optimal.nf)의 `DADA2_TRIMM_SWEEP` |
| 최적화 순위·species 판정 | `optimal_min_sample_reads`는 보고 기준만 변경 | 같은 파일의 `TAXONOMY_TRIMM_SWEEP`, `SELECT_TRIMM_OPTIMAL` |
| Taxonomy | `classifier`, `taxonomy_confidence: 0.7`, `taxonomy_label: AUTO` | 최종 분석: [modules/qiime_taxonomy.nf](modules/qiime_taxonomy.nf); 후보 분석: `modules/trimm_optimal.nf` |
| MAFFT·FastTree 옵션 | 별도 분석 파라미터 없음 | [modules/qiime_phylogeny.nf](modules/qiime_phylogeny.nf) |
| 다양성·rarefaction | `diversity_enabled`, `sampling_depth: 1000`, `alpha_max_depth: 10000` | [modules/qiime_diversity.nf](modules/qiime_diversity.nf) |

DADA2의 `trunc-q`, chimera 방식처럼 명령에 고정된 옵션을 바꾸려면 **일반 모듈과 최적화 모듈 양쪽**을 확인해야 합니다. Taxonomy 명령 변경도 후보 평가와 최종 분석에 일관되게 적용합니다. 새 파라미터를 추가한다면 `nextflow.config`, [nextflow_schema.json](nextflow_schema.json), 해당 모듈과 문서를 함께 갱신합니다.

도구 버전을 변경할 때는 SIF 경로만 교체하는 것으로 충분한지, 모듈의 명령 옵션과 classifier 호환성까지 확인합니다. 최종 연구 분석에는 사용한 컨테이너 버전과 classifier를 함께 기록합니다.

## 5. 결과 확인

| 경로 (`outdir` 아래) | 내용 |
|---|---|
| `01_raw_qc/`, `03_clean_qc/` | 처리 전·후 FastQC/MultiQC |
| `02_cutadapt_q20/` | Primer 제거 FASTQ, Cutadapt 로그·JSON. 폴더명은 quality 설정과 관계없이 고정 |
| `04_qiime2_import/` | Manifest, paired-end QZA, 품질 요약 |
| `05_dada2/` | 최적화가 꺼진 일반 DADA2 결과 및 요약 |
| `05_trimm_optimal_dada2/` | 최적화 후보별 DADA2 결과 |
| `05_trimm_optimal_<LABEL>/` | 후보별 taxonomy 및 지표 |
| `05_trimm_optimal_<LABEL>/selected/` | 전체 순위, 선택 길이, 선택된 QZA |
| `06_taxonomy/` | `taxonomy_<LABEL>.qza`, `taxa-bar-plots_<LABEL>.qzv` 등 |
| `07_phylogeny/`, `08_diversity/` | 계통수 및 활성화한 경우 다양성 결과 |

최적화 후에는 다음 파일을 먼저 확인합니다.

- `all_parameter_results.tsv`: 성공한 후보의 전체 순위와 지표.
- `optimal_selection.tsv`, `optimal_truncation.txt`: 선택된 F/R 길이와 평가 결과.
- `selected-table.qza`, `selected-rep-seqs.qza`, `selected-denoising-stats.qza`: 후속 분석에 사용한 결과.

`taxonomy_label: AUTO`는 classifier 경로에서 SILVA/GG2/GTDB 등을 추론합니다. 연구자가 `SILVA`, `GG2` 등의 값을 직접 지정해 결과를 구분할 수도 있습니다. 최적화 모드에는 일반 모드의 `05_dada2/table-summary.qzv`가 생성되지 않으므로 선택된 table과 stats를 확인해 다양성 분석 깊이를 결정합니다.

## 6. 코드 구조와 검증

```text
main.nf                  # 전체 단계 연결, 분기 및 입력 확인
nextflow.config          # 공통 기본값·컨테이너·실행 설정
nextflow_schema.json     # 파라미터 명세
conf/base.config         # 작업 자원 기본값
lib/PrimerConfig.groovy  # 영역별 primer 및 adapter 해석
params/
  regions/               # V1V3, V3V4 선택용 YAML
  examples/              # 사용자 primer YAML 예시
  trimming/              # 기본 F/R 후보 TSV
modules/                 # 각 분석 도구의 실제 process 명령
subworkflows/
  qc.nf                  # raw/clean 공통 FastQC → MultiQC
  trimm_optimal.nf        # 후보 입력 → 실행 → 비교·선택 연결
tests/                   # 합성 FASTQ와 primer 회귀 테스트
```

단일 도구는 `main.nf`에서 모듈을 직접 호출합니다. 여러 단계를 연결하는 QC와 절단 길이 최적화만 subworkflow로 유지합니다.

Primer 테스트 실행 방법은 [tests/README.md](tests/README.md)에 있습니다. 이 테스트는 기본 primer, 덮어쓰기 우선순위, adapter 계산과 합성 FASTQ trimming을 확인하며, 전체 QIIME 2 분석이나 최적 조합의 생물학적 타당성을 검증하는 테스트는 아닙니다.

## Containers and CI / 컨테이너와 CI

Each process in `modules/*.nf` declares a versioned public container:

| Tool | Image |
|---|---|
| FastQC | `quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0` |
| MultiQC | `quay.io/biocontainers/multiqc:1.27--pyhdfd78af_0` |
| Cutadapt | `quay.io/biocontainers/cutadapt:5.2--py311hc303176_2` |
| QIIME 2 | `quay.io/qiime2/amplicon:2025.7` |

Singularity/Apptainer directives use `docker://`; Docker uses the same image without that prefix, as required by [Nextflow](https://docs.seqera.io/nextflow/container/singularity). The runtime itself must already be installed. First use requires registry access and enough disk space, especially for QIIME 2. For a reusable Singularity cache, set `NXF_SINGULARITY_CACHEDIR` to a writable directory (shared across compute nodes on HPC); for Apptainer use `NXF_APPTAINER_CACHEDIR`.

이미 보유한 로컬 SIF가 있다면 외부 `analysis.yml`에 아래 설정을 추가하고 `-profile singularity` 또는 `-profile apptainer`로 실행합니다. 지정한 이미지를 공개 이미지보다 우선 사용합니다. `qc_sif`에는 FastQC와 MultiQC가 모두 있어야 합니다. Docker 프로필에서는 SIF 파일을 사용할 수 없습니다.

```yaml
# Optional local overrides; omit these to download public images automatically.
qc_sif: "/absolute/path/to/qc_fastqc_multiqc.sif"
cutadapt_sif: "/absolute/path/to/read_cleanup_cutadapt-5.2.sif"
qiime_sif: "/absolute/path/to/qiime2_amplicon_2025.7.sif"
```

Run the synthetic primer regression without biological input data:

```bash
nextflow run . -profile test,docker
python3 tests/check_trimmed.py results/primer-test
# HPC alternative:
nextflow run . -profile test,singularity
```

`test` runs only primer assertions and real Cutadapt trimming on bundled synthetic FASTQ. It does not test the full QIIME 2 pipeline. The output verifier checks that both mates contain exactly one 60-base T sequence. See [tests/README.md](tests/README.md) for YAML/CLI precedence testing.

[GitHub Actions](.github/workflows/ci.yml) runs this regression and output verification on every push and pull request. A `v*` tag publishes a GitHub release only after that tag's test passes.
