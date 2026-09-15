process QIIME_TAXONOMY {
    tag "${params.run_label}:${taxonomy_label}"
    label 'process_high'
    container params.qiime_sif

    publishDir "${params.outdir}/06_taxonomy", mode: 'copy', overwrite: true

    input:
    path repseq
    path table
    path metadata
    path classifier
    val taxonomy_label

    output:
    path "taxonomy_${taxonomy_label}.qza",       emit: taxonomy
    path "taxonomy_${taxonomy_label}.qzv",       emit: taxonomy_summary
    path "taxa-bar-plots_${taxonomy_label}.qzv", emit: barplot
    path "versions_${taxonomy_label}.yml",       emit: versions

    script:
    """
    export TMPDIR=\"\$PWD/tmp\" NUMBA_CACHE_DIR=\"\$PWD/numba\" MPLCONFIGDIR=\"\$PWD/mpl\" XDG_CACHE_HOME=\"\$PWD/cache\"
    mkdir -p \"\$TMPDIR\" \"\$NUMBA_CACHE_DIR\" \"\$MPLCONFIGDIR\" \"\$XDG_CACHE_HOME\"

    qiime feature-classifier classify-sklearn \
      --i-classifier ${classifier} \
      --i-reads ${repseq} \
      --p-confidence ${params.taxonomy_confidence} \
      --p-n-jobs ${task.cpus} \
      --o-classification taxonomy_${taxonomy_label}.qza

    qiime metadata tabulate \
      --m-input-file taxonomy_${taxonomy_label}.qza \
      --o-visualization taxonomy_${taxonomy_label}.qzv

    qiime taxa barplot \
      --i-table ${table} \
      --i-taxonomy taxonomy_${taxonomy_label}.qza \
      --m-metadata-file ${metadata} \
      --o-visualization taxa-bar-plots_${taxonomy_label}.qzv

    cat <<-END_VERSIONS > versions_${taxonomy_label}.yml
    "${task.process}":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
