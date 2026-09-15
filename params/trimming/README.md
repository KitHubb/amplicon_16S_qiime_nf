# 영역별 F/R 절단 길이 후보

## 근거와 길이 가정

이 TSV의 후보는 **문헌에서 보고한 amplicon 길이를 바탕으로 설계한 탐색 후보**입니다. 논문에서 이 조합들을 직접 검증하거나 최적이라고 제시한 것은 아닙니다. 평균 길이의 대용으로 문헌의 대략적인 대표 길이를 사용했으며, 실제 샘플의 평균·분포를 측정한 값은 아닙니다.

| 영역 | Primer | 문헌 기반 PCR 산물 대표 길이¹ | 현재 primer 길이 F/R | Primer 제거 후 계산 길이 L |
|---|---|---:|---:|---:|
| V1V3 | 27F/534R | 약 500 bp | 19/16 nt | 약 465 bp |
| V3V4 | 341F/805R | 약 460 bp | 17/21 nt | 약 422 bp |

¹ Sequencing adapter·index를 제외하고 양 끝 locus primer를 포함하는 산물 길이로 가정했습니다. Primer 제거 후 길이가 보고된 자료에서 primer 길이를 다시 빼면 안 됩니다.

- **V1V3:** [Kirkegaard et al., 2016, ISME Journal, doi:10.1038/ismej.2016.43](https://www.nature.com/articles/ismej201643)의 Community profiling 절은 저장소와 동일한 27F/534R 서열과 약 500 bp 산물, 2×300 bp sequencing을 설명합니다.
- **V3V4:** [Woruba et al., 2019, BMC Microbiology, doi:10.1186/s12866-019-1649-6](https://link.springer.com/article/10.1186/s12866-019-1649-6)는 341F/805R로 약 460 bp를 표적합니다. [Zheng et al., 2015, Table 1, doi:10.1186/s40168-015-0110-9](https://pmc.ncbi.nlm.nih.gov/articles/PMC4593206/)에서 현재 V3V4 primer 서열을 확인할 수 있습니다.
- **최소 overlap:** [QIIME 2 DADA2 denoise-paired 공식 문서](https://docs.qiime2.org/2024.10/plugins/available/dada2/denoise-paired/)의 기본값은 12 nt입니다. 일반·최적화 DADA2 명령에 `--p-min-overlap 12`를 명시했습니다.

## 계산과 선택

```text
L = PCR 산물 길이 − forward primer 길이 − reverse primer 길이
예상 overlap = trunc_len_f + trunc_len_r − L
최소 merge 조건: F + R >= L + 12
후보 설계 조건: F + R >= 520 (V1V3), 480 (V3V4)
```

현재 파이프라인은 Cutadapt로 primer를 먼저 제거하고 DADA2의 trim-left는 0을 사용합니다. 따라서 TSV의 F/R은 원시 300 bp read의 길이가 아니라 **primer 제거 후 유지할 길이**입니다.

모든 후보는 F > R, 10 nt 단위입니다. V1V3는 6쌍, V3V4는 10쌍입니다. 2×300에서 primer만 제거하면 V1V3는 최대 F281/R284, V3V4는 F283/R279가 남으므로, 제시한 후보는 이 상한을 넘지 않습니다. Q20 trimming을 거치면 실제 reads는 더 짧아질 수 있고 DADA2는 후보 절단 길이보다 짧은 reads를 제외합니다.

설계 하한은 V1V3 F+R−20 ≥ 500 bp, V3V4 F+R−20 ≥ 460 bp입니다. 앞의 465/422 bp 추정값을 설계 하한으로 사용하지 않습니다. 표 순서는 성능 순위가 아닙니다. **F+R−20은 실제 병합 길이가 아니라 20 bp overlap을 확보할 수 있는 최대 insert 길이**입니다. 실제 overlap은 F+R−실제 insert 길이입니다.

[DADA2 공식 tutorial](https://benjjneb.github.io/dada2/tutorial.html)은 20 nt에 생물학적 길이 변이를 더한 overlap을 권고합니다. 후보 설계 목표는 대표 길이 대비 overlap 20 bp 이상이며, 실행 시 최소 merge 허용값은 12 bp입니다. 대표 길이는 전체 세균의 실측 평균이 아니므로 긴 분류군의 병합을 보장하지 않습니다.

### V1V3

설계 하한은 F+R−20 ≥ 500 bp입니다. 500 bp는 세균 전체의 최대값으로 검증된 값이 아닙니다. Primer 제거 후 read 상한과 F > R 조건에서 10 nt 간격으로 가능한 조합 6개를 모두 사용합니다.

| F | R | F+R−20 | L=500일 때 overlap |
|---:|---:|---:|---:|
| 270 | 250 | 500 | 20 |
| 280 | 240 | 500 | 20 |
| 270 | 260 | 510 | 30 |
| 280 | 250 | 510 | 30 |
| 280 | 260 | 520 | 40 |
| 280 | 270 | 530 | 50 |

### V3V4

사용자 지정 설계 하한은 **F+R−20 ≥ 460 bp**, 즉 **F+R ≥ 480 bp**입니다. 460 bp를 문헌에서 확인한 최대값으로 해석하지 않습니다. 앞의 primer 제거 후 약 422 bp는 참고 추정치이며 이 후보의 설계 하한으로 사용하지 않습니다.

| F | R | F+R−20 | L=460일 때 overlap |
|---:|---:|---:|---:|
| 250 | 230 | 460 | 20 |
| 260 | 220 | 460 | 20 |
| 270 | 210 | 460 | 20 |
| 280 | 200 | 460 | 20 |
| 250 | 240 | 470 | 30 |
| 260 | 230 | 470 | 30 |
| 270 | 220 | 470 | 30 |
| 280 | 210 | 470 | 30 |
| 270 | 230 | 480 | 40 |
| 280 | 220 | 480 | 40 |

## 사용과 한계

- `--trimm_optimal true --region V1V3`: `v1v3_10bp.tsv` 자동 선택.
- `--trimm_optimal true --region V3V4`: `v3v4_10bp.tsv` 자동 선택.
- `--trimm_combinations /path/to/custom.tsv` 또는 외부 YAML로 지정한 파일이 영역 기본값보다 우선합니다.
- 기존 `trimm_combinations_10bp.tsv`는 `v1v3_10bp.tsv`로 이름을 변경했습니다. 이를 명시했던 외부 실행 명령은 경로를 바꾸거나 해당 옵션을 생략하세요.
- 이 값은 실제 merge 성공을 보장하지 않습니다. 분류군별 insert 길이, read 품질, mismatch, indel에 따라 달라집니다. F+R−20보다 긴 insert는 20 bp overlap을 확보하지 못하며, F+R−12보다 길면 최소 merge 조건도 만족하지 못합니다.
- 기본 primer와 다른 위치를 표적하는 사용자 primer를 지정하면 후보 파일을 별도로 준비하세요. 파일은 region으로 선택되며 사용자 primer의 실제 amplicon 길이를 자동 추정하지 않습니다.
- 실제 최적 조합은 `all_parameter_results.tsv`와 DADA2의 merge/non-chimeric 통계를 보고 결정합니다. 문헌 기반 평균 가정만으로 긴 분류군의 손실을 배제할 수 없습니다.
