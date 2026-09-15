process QIIME_IMPORT {
    tag params.run_label
    label 'process_medium'
    container params.qiime_sif

    publishDir "${params.outdir}/04_qiime2_import", mode: 'copy', overwrite: true

    input:
    path clean_fastqs

    output:
    path 'manifest.tsv',      emit: manifest
    path 'demux-paired.qza',  emit: demux
    path 'demux-summary.qzv', emit: summary
    path 'versions.yml',      emit: versions

    script:
    """
    export TMPDIR=\"\$PWD/tmp\" XDG_CACHE_HOME=\"\$PWD/cache\"
    mkdir -p \"\$TMPDIR\" \"\$XDG_CACHE_HOME\"

    printf 'sample-id\tforward-absolute-filepath\treverse-absolute-filepath\n' > manifest.tsv
    for r1 in *.R1.trimmed.fastq.gz; do
      sample=\"\${r1%.R1.trimmed.fastq.gz}\"
      r2=\"\${sample}.R2.trimmed.fastq.gz\"
      test -f \"\$r2\"
      printf '%s\t%s/%s\t%s/%s\n' \"\$sample\" \"\$PWD\" \"\$r1\" \"\$PWD\" \"\$r2\" >> manifest.tsv
    done

    qiime tools import \
      --type 'SampleData[PairedEndSequencesWithQuality]' \
      --input-path manifest.tsv \
      --input-format PairedEndFastqManifestPhred33V2 \
      --output-path demux-paired.qza

    qiime demux summarize \
      --i-data demux-paired.qza \
      --o-visualization demux-summary.qzv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
