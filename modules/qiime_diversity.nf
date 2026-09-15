process QIIME_DIVERSITY {
    tag params.run_label
    label 'process_high'
    container params.qiime_sif

    publishDir "${params.outdir}/08_diversity", mode: 'copy', overwrite: true

    input:
    path table
    path rooted_tree
    path metadata

    output:
    path 'core-metrics-results',              emit: core_metrics
    path 'alpha-rarefaction.qzv',             emit: alpha_rarefaction
    path 'faith-pd-group-significance.qzv',   emit: faith_group
    path 'observed-group-significance.qzv',   emit: observed_group
    path 'shannon-group-significance.qzv',    emit: shannon_group
    path 'evenness-group-significance.qzv',   emit: evenness_group
    path 'versions.yml',                      emit: versions

    script:
    """
    export TMPDIR=\"\$PWD/tmp\" NUMBA_CACHE_DIR=\"\$PWD/numba\" MPLCONFIGDIR=\"\$PWD/mpl\" XDG_CACHE_HOME=\"\$PWD/cache\"
    mkdir -p \"\$TMPDIR\" \"\$NUMBA_CACHE_DIR\" \"\$MPLCONFIGDIR\" \"\$XDG_CACHE_HOME\"

    qiime diversity core-metrics-phylogenetic \
      --i-phylogeny ${rooted_tree} \
      --i-table ${table} \
      --p-sampling-depth ${params.sampling_depth} \
      --m-metadata-file ${metadata} \
      --p-n-jobs-or-threads ${task.cpus} \
      --output-dir core-metrics-results

    qiime diversity alpha-rarefaction \
      --i-table ${table} \
      --i-phylogeny ${rooted_tree} \
      --p-max-depth ${params.alpha_max_depth} \
      --m-metadata-file ${metadata} \
      --o-visualization alpha-rarefaction.qzv

    qiime diversity alpha-group-significance \
      --i-alpha-diversity core-metrics-results/faith_pd_vector.qza \
      --m-metadata-file ${metadata} \
      --o-visualization faith-pd-group-significance.qzv

    qiime diversity alpha-group-significance \
      --i-alpha-diversity core-metrics-results/observed_features_vector.qza \
      --m-metadata-file ${metadata} \
      --o-visualization observed-group-significance.qzv

    qiime diversity alpha-group-significance \
      --i-alpha-diversity core-metrics-results/shannon_vector.qza \
      --m-metadata-file ${metadata} \
      --o-visualization shannon-group-significance.qzv

    qiime diversity alpha-group-significance \
      --i-alpha-diversity core-metrics-results/evenness_vector.qza \
      --m-metadata-file ${metadata} \
      --o-visualization evenness-group-significance.qzv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
