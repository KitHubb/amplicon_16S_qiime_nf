process QIIME_CONTAINER_CHECK {
    label 'process_medium'
    container { params.qiime_sif ?: (workflow.containerEngine == 'docker' ? 'quay.io/qiime2/amplicon:2025.7' : 'docker://quay.io/qiime2/amplicon:2025.7') }
    publishDir "${params.outdir}/container_checks", mode: 'copy', overwrite: true

    output:
    path 'qiime-container.txt'

    script:
    """
    export TMPDIR="\$PWD/tmp" XDG_CACHE_HOME="\$PWD/cache"
    export MPLCONFIGDIR="\$PWD/mpl" NUMBA_CACHE_DIR="\$PWD/numba"
    mkdir -p "\$TMPDIR" "\$XDG_CACHE_HOME" "\$MPLCONFIGDIR" "\$NUMBA_CACHE_DIR"
    qiime info > qiime-container.txt
    qiime dada2 denoise-paired --help > /dev/null
    qiime feature-classifier classify-sklearn --help > /dev/null
    qiime phylogeny align-to-tree-mafft-fasttree --help > /dev/null
    qiime diversity core-metrics-phylogenetic --help > /dev/null
    qiime diversity alpha-rarefaction --help > /dev/null
    qiime taxa barplot --help > /dev/null
    printf '\nPASS: required QIIME actions are available\n' >> qiime-container.txt
    """
}
