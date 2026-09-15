# 영역별 F/R 절단 길이 후보

## 근거와 길이 가정

이 TSV의 10쌍은 **문헌에서 보고한 amplicon 길이를 바탕으로 설계한 탐색 후보**입니다. 논문에서 이 10쌍을 직접 검증하거나 최적이라고 제시한 것은 아닙니다. 평균 길이의 대용으로 문헌의 대략적인 대표 길이를 사용했으며, 실제 샘플의 평균·분포를 측정한 값은 아닙니다.

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
최소 조건: F + R >= L + 12
```

현재 파이프라인은 Cutadapt로 primer를 먼저 제거하고 DADA2의 trim-left는 0을 사용합니다. 따라서 TSV의 F/R은 원시 300 bp read의 길이가 아니라 **primer 제거 후 유지할 길이**입니다.

모든 후보는 F > R, 10 nt 단위입니다. 2×300에서 primer만 제거하면 V1V3는 최대 F281/R284, V3V4는 F283/R279가 남으므로, 제시한 후보는 이 상한을 넘지 않습니다. Q20 trimming을 거치면 실제 reads는 더 짧아질 수 있고 DADA2는 후보 절단 길이보다 짧은 reads를 제외합니다.

V1V3는 긴 insert를 고려해 F260–280/R230–270의 기존 후보를 유지했습니다. 계산 overlap은 35–85 bp입니다. V3V4는 짧은 insert를 활용하여 F250–280/R210–240에서 reverse 말단 절단을 더 탐색하며, 계산 overlap은 38–78 bp입니다. 최소 12 bp에 정확히 맞추기보다 대표 길이 오차에 대한 여유를 두었습니다. 같은 F+R 합계의 서로 다른 F/R 배분도 비교합니다.

### V1V3

| F | R | F+R | 예상 overlap | 허용 insert 최대 길이 (F+R−12) |
|---:|---:|---:|---:|---:|
| 280 | 270 | 550 | 85 | 538 |
| 280 | 260 | 540 | 75 | 528 |
| 280 | 250 | 530 | 65 | 518 |
| 280 | 240 | 520 | 55 | 508 |
| 280 | 230 | 510 | 45 | 498 |
| 270 | 260 | 530 | 65 | 518 |
| 270 | 250 | 520 | 55 | 508 |
| 270 | 240 | 510 | 45 | 498 |
| 270 | 230 | 500 | 35 | 488 |
| 260 | 250 | 510 | 45 | 498 |

### V3V4

| F | R | F+R | 예상 overlap | 허용 insert 최대 길이 (F+R−12) |
|---:|---:|---:|---:|---:|
| 280 | 220 | 500 | 78 | 488 |
| 270 | 230 | 500 | 78 | 488 |
| 270 | 220 | 490 | 68 | 478 |
| 260 | 240 | 500 | 78 | 488 |
| 260 | 230 | 490 | 68 | 478 |
| 260 | 220 | 480 | 58 | 468 |
| 250 | 240 | 490 | 68 | 478 |
| 250 | 230 | 480 | 58 | 468 |
| 250 | 220 | 470 | 48 | 458 |
| 250 | 210 | 460 | 38 | 448 |

## 사용과 한계

- `--trimm_optimal true --region V1V3`: `v1v3_10bp.tsv` 자동 선택.
- `--trimm_optimal true --region V3V4`: `v3v4_10bp.tsv` 자동 선택.
- `--trimm_combinations /path/to/custom.tsv` 또는 외부 YAML로 지정한 파일이 영역 기본값보다 우선합니다.
- 기존 `trimm_combinations_10bp.tsv`는 `v1v3_10bp.tsv`로 이름을 변경했습니다. 이를 명시했던 외부 실행 명령은 경로를 바꾸거나 해당 옵션을 생략하세요.
- 이 값은 실제 merge 성공을 보장하지 않습니다. 분류군별 insert 길이, read 품질, mismatch, indel에 따라 달라집니다. 표의 최대 insert 길이를 넘는 서열은 해당 후보에서 12 bp overlap을 확보하지 못합니다.
- 기본 primer와 다른 위치를 표적하는 사용자 primer를 지정하면 후보 파일을 별도로 준비하세요. 파일은 region으로 선택되며 사용자 primer의 실제 amplicon 길이를 자동 추정하지 않습니다.
- 실제 최적 조합은 `all_parameter_results.tsv`와 DADA2의 merge/non-chimeric 통계를 보고 결정합니다. 문헌 기반 평균 가정만으로 긴 분류군의 손실을 배제할 수 없습니다.
