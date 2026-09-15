process DADA2_TRIMM_SWEEP {
    tag "${opt_id}:F${trunc_f}_R${trunc_r}"
    label 'process_high'
    container params.qiime_sif
    errorStrategy 'ignore'

    publishDir "${params.outdir}/trimm_optimal_dada2", mode: 'copy', overwrite: true

    input:
    tuple val(opt_id), val(trunc_f), val(trunc_r), path(demux)

    output:
    tuple val(opt_id), val(trunc_f), val(trunc_r),
          path("${opt_id}.table.qza"), path("${opt_id}.rep-seqs.qza"),
          path("${opt_id}.denoising-stats.qza"), emit: results

    script:
    """
    export TMPDIR="\$PWD/tmp" NUMBA_CACHE_DIR="\$PWD/numba" MPLCONFIGDIR="\$PWD/mpl" XDG_CACHE_HOME="\$PWD/cache"
    mkdir -p "\$TMPDIR" "\$NUMBA_CACHE_DIR" "\$MPLCONFIGDIR" "\$XDG_CACHE_HOME"

    qiime dada2 denoise-paired \
      --i-demultiplexed-seqs ${demux} \
      --p-trim-left-f 0 --p-trim-left-r 0 \
      --p-trunc-len-f ${trunc_f} --p-trunc-len-r ${trunc_r} \
      --p-max-ee-f ${params.dada2_max_ee_f} --p-max-ee-r ${params.dada2_max_ee_r} \
      --p-trunc-q 2 --p-chimera-method consensus --p-n-threads ${task.cpus} \
      --o-table ${opt_id}.table.qza \
      --o-representative-sequences ${opt_id}.rep-seqs.qza \
      --o-denoising-stats ${opt_id}.denoising-stats.qza
    """
}

process TAXONOMY_TRIMM_SWEEP {
    tag "${taxonomy_label}:${opt_id}"
    label 'process_high'
    container params.qiime_sif
    errorStrategy 'ignore'

    publishDir "${params.outdir}", mode: 'copy', overwrite: true,
        saveAs: { filename -> "trimm_optimal_${taxonomy_label}/${filename}" }

    input:
    tuple val(opt_id), val(trunc_f), val(trunc_r), path(table), path(repseq), path(stats)
    path classifier
    val taxonomy_label

    output:
    tuple val(taxonomy_label), val(opt_id), val(trunc_f), val(trunc_r), path(table), path(repseq), path(stats),
          path("${opt_id}.taxonomy.qza"), path("${opt_id}.metrics.tsv"), emit: evaluated

    script:
    """
    export TMPDIR="\$PWD/tmp" NUMBA_CACHE_DIR="\$PWD/numba" MPLCONFIGDIR="\$PWD/mpl" XDG_CACHE_HOME="\$PWD/cache"
    mkdir -p "\$TMPDIR" "\$NUMBA_CACHE_DIR" "\$MPLCONFIGDIR" "\$XDG_CACHE_HOME" stats_export table_export tax_export

    qiime feature-classifier classify-sklearn \
      --i-classifier ${classifier} --i-reads ${repseq} \
      --p-confidence ${params.taxonomy_confidence} --p-n-jobs ${task.cpus} \
      --o-classification ${opt_id}.taxonomy.qza

    qiime tools export --input-path ${stats} --output-path stats_export
    qiime tools export --input-path ${table} --output-path table_export
    qiime tools export --input-path ${opt_id}.taxonomy.qza --output-path tax_export
    biom convert -i table_export/feature-table.biom -o feature-table.tsv --to-tsv

    python - "${taxonomy_label}" "${opt_id}" "${trunc_f}" "${trunc_r}" "${params.optimal_min_sample_reads}" <<'PY'
import csv, re, sys
from pathlib import Path

reference_db, opt_id = sys.argv[1], sys.argv[2]
trunc_f, trunc_r, min_reads = int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])

stats_file = next(Path('stats_export').glob('*.tsv'))
with stats_file.open() as handle:
    rows = [r for r in csv.DictReader((line for line in handle if not line.startswith('#')), delimiter=chr(9))]

def total(column):
    return sum(float(r[column]) for r in rows)

input_reads = total('input')
filtered = total('filtered')
merged = total('merged')
nonchim = total('non-chimeric')
low_depth = sum(float(r['non-chimeric']) < min_reads for r in rows)
zero_merge = sum(float(r['merged']) == 0 for r in rows)

taxonomy_file = next(Path('tax_export').glob('*.tsv'))
taxonomy = {}
with taxonomy_file.open() as handle:
    for row in csv.DictReader(handle, delimiter=chr(9)):
        fid = row.get('Feature ID') or row.get('feature-id') or row.get('FeatureID')
        taxon = row.get('Taxon', '')
        terminal = taxon.split(';')[-1].strip()
        species_name = re.sub(r'^(s__|s:)\s*', '', terminal, flags=re.I).strip()
        valid = bool(re.search(r'(^|;)\s*(s__|s:)', taxon, re.I))
        valid = valid and bool(species_name)
        valid = valid and not re.search(r'(uncultured|unidentified|unknown|metagenome|unclassified|ambiguous)', species_name, re.I)
        valid = valid and species_name.lower() not in {'sp', 'sp.'}
        taxonomy[fid] = valid

feature_reads = {}
with open('feature-table.tsv') as handle:
    reader = csv.reader((line for line in handle if not line.startswith('# Constructed')), delimiter=chr(9))
    header = next(reader)
    for row in reader:
        feature_reads[row[0]] = sum(float(x) for x in row[1:])

total_asvs = len(feature_reads)
species_asvs = sum(bool(taxonomy.get(fid)) for fid in feature_reads)
table_reads = sum(feature_reads.values())
species_reads = sum(count for fid, count in feature_reads.items() if taxonomy.get(fid))

def pct(a, b):
    return 0.0 if not b else 100.0 * a / b

fields = ['reference_db','parameter_set','trunc_len_f','trunc_len_r','samples','input_reads','filtered_pct','merged_pct',
          'nonchimeric_reads','nonchimeric_pct','total_asvs','species_asvs','species_asv_pct',
          'species_reads','species_read_pct','species_input_yield','samples_below_min_reads','zero_merge_samples']
values = [reference_db,opt_id,trunc_f,trunc_r,len(rows),int(input_reads),pct(filtered,input_reads),pct(merged,input_reads),
          int(nonchim),pct(nonchim,input_reads),total_asvs,species_asvs,pct(species_asvs,total_asvs),
          int(species_reads),pct(species_reads,table_reads),pct(species_reads,input_reads),low_depth,zero_merge]
with open(f'{opt_id}.metrics.tsv','w',newline='') as handle:
    writer=csv.writer(handle,delimiter=chr(9))
    writer.writerow(fields)
    writer.writerow([f'{x:.4f}' if isinstance(x,float) else x for x in values])
PY
    """
}

process SELECT_TRIMM_OPTIMAL {
    tag "${taxonomy_label}:rank_all_candidates"
    label 'process_low'
    container params.qiime_sif

    publishDir "${params.outdir}", mode: 'copy', overwrite: true,
        saveAs: { filename -> "trimm_optimal_${taxonomy_label}/selected/${filename}" }

    input:
    val taxonomy_label
    path candidate_files

    output:
    path 'optimal_selection.tsv', emit: selection
    path 'all_parameter_results.tsv', emit: comparison
    path 'optimal_truncation.txt', emit: selected_params
    path 'selected-table.qza', emit: table
    path 'selected-rep-seqs.qza', emit: repseq
    path 'selected-denoising-stats.qza', emit: stats

    script:
    """
    python - <<'PY'
import csv, shutil, sys
from pathlib import Path

rows=[]
for path in sorted(Path('.').glob('*.metrics.tsv')):
    with path.open() as handle:
        row=next(csv.DictReader(handle,delimiter=chr(9)))
    for key in ['nonchimeric_pct','species_asv_pct','species_read_pct','species_input_yield']:
        row[key]=float(row[key])
    for key in ['samples_below_min_reads','zero_merge_samples']:
        row[key]=int(row[key])
    rows.append(row)

if not rows:
    raise SystemExit('No truncation candidate completed DADA2 and taxonomy successfully')

rows.sort(key=lambda r:(r['species_input_yield'],r['species_read_pct'],r['nonchimeric_pct']), reverse=True)
for rank, row in enumerate(rows, start=1):
    row['rank']=rank
winner=rows[0].copy()
winner['selection_status']='TOP_RANKED_FROM_ALL_COMPLETED_CANDIDATES'

fields=list(rows[0].keys())
with open('all_parameter_results.tsv','w',newline='') as handle:
    writer=csv.DictWriter(handle,fieldnames=fields,delimiter=chr(9))
    writer.writeheader(); writer.writerows(rows)
with open('optimal_selection.tsv','w',newline='') as handle:
    fields2=list(winner.keys())
    writer=csv.DictWriter(handle,fieldnames=fields2,delimiter=chr(9))
    writer.writeheader(); writer.writerow(winner)
with open('optimal_truncation.txt','w') as handle:
    print('parameter_set', winner['parameter_set'], sep=chr(9), file=handle)
    print('dada2_trunc_len_f', winner['trunc_len_f'], sep=chr(9), file=handle)
    print('dada2_trunc_len_r', winner['trunc_len_r'], sep=chr(9), file=handle)
    print('selection_status', winner['selection_status'], sep=chr(9), file=handle)

prefix=winner['parameter_set']
shutil.copyfile(f'{prefix}.table.qza','selected-table.qza')
shutil.copyfile(f'{prefix}.rep-seqs.qza','selected-rep-seqs.qza')
shutil.copyfile(f'{prefix}.denoising-stats.qza','selected-denoising-stats.qza')
PY
    """
}
