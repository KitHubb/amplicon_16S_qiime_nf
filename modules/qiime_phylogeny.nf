process QIIME_PHYLOGENY {
    tag params.run_label
    label 'process_high'
    container params.qiime_sif

    publishDir "${params.outdir}/07_phylogeny", mode: 'copy', overwrite: true

    input:
    path repseq

    output:
    path 'aligned-rep-seqs.qza',        emit: alignment
    path 'masked-aligned-rep-seqs.qza', emit: masked_alignment
    path 'unrooted-tree.qza',           emit: unrooted_tree
    path 'rooted-tree.qza',             emit: rooted_tree
    path 'versions.yml',                emit: versions

    script:
    """
    export TMPDIR=\"\$PWD/tmp\" NUMBA_CACHE_DIR=\"\$PWD/numba\" MPLCONFIGDIR=\"\$PWD/mpl\" XDG_CACHE_HOME=\"\$PWD/cache\"
    mkdir -p \"\$TMPDIR\" \"\$NUMBA_CACHE_DIR\" \"\$MPLCONFIGDIR\" \"\$XDG_CACHE_HOME\"

    qiime phylogeny align-to-tree-mafft-fasttree \
      --i-sequences ${repseq} \
      --p-n-threads ${task.cpus} \
      --o-alignment aligned-rep-seqs.qza \
      --o-masked-alignment masked-aligned-rep-seqs.qza \
      --o-tree unrooted-tree.qza \
      --o-rooted-tree rooted-tree.qza

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
