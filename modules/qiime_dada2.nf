process QIIME_DADA2 {
    tag params.run_label
    label 'process_high'
    container params.qiime_sif

    publishDir "${params.outdir}/05_dada2", mode: 'copy', overwrite: true

    input:
    path demux

    output:
    path 'table.qza',             emit: table
    path 'rep-seqs.qza',          emit: repseq
    path 'denoising-stats.qza',   emit: stats
    path 'denoising-stats.qzv',   emit: stats_summary
    path 'table-summary.qzv',     emit: table_summary
    path 'rep-seqs.qzv',          emit: repseq_summary
    path 'versions.yml',          emit: versions

    script:
    """
    export TMPDIR=\"\$PWD/tmp\" NUMBA_CACHE_DIR=\"\$PWD/numba\" MPLCONFIGDIR=\"\$PWD/mpl\" XDG_CACHE_HOME=\"\$PWD/cache\"
    mkdir -p \"\$TMPDIR\" \"\$NUMBA_CACHE_DIR\" \"\$MPLCONFIGDIR\" \"\$XDG_CACHE_HOME\"

    qiime dada2 denoise-paired \
      --i-demultiplexed-seqs ${demux} \
      --p-trim-left-f 0 --p-trim-left-r 0 \
      --p-trunc-len-f ${params.dada2_trunc_len_f} \
      --p-trunc-len-r ${params.dada2_trunc_len_r} \
      --p-max-ee-f ${params.dada2_max_ee_f} \
      --p-max-ee-r ${params.dada2_max_ee_r} \
      --p-trunc-q 2 \
      --p-chimera-method consensus \
      --p-n-threads ${task.cpus} \
      --o-table table.qza \
      --o-representative-sequences rep-seqs.qza \
      --o-denoising-stats denoising-stats.qza

    qiime metadata tabulate --m-input-file denoising-stats.qza --o-visualization denoising-stats.qzv
    qiime feature-table summarize --i-table table.qza --o-visualization table-summary.qzv
    qiime feature-table tabulate-seqs --i-data rep-seqs.qza --o-visualization rep-seqs.qzv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
