process CUTADAPT {
    tag meta.id
    label 'process_medium'
    container params.cutadapt_sif

    publishDir "${params.outdir}/02_cutadapt_q20", mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(r1), path(r2)
    val primers

    output:
    tuple val(meta),
          path("${meta.id}.R1.trimmed.fastq.gz"),
          path("${meta.id}.R2.trimmed.fastq.gz"),
          emit: reads
    path "${meta.id}.cutadapt.json", emit: json
    path "${meta.id}.cutadapt.log",  emit: cutadapt_log
    path 'versions.yml',              emit: versions

    script:
    """
    cutadapt --cores ${task.cpus} \
      -g '${primers.primer_f}' -a '${primers.adapter_f}' \
      -G '${primers.primer_r}' -A '${primers.adapter_r}' \
      -n 2 -q ${params.quality} -Q ${params.quality} \
      --minimum-length ${params.min_length} \
      --discard-untrimmed \
      --json ${meta.id}.cutadapt.json \
      -o ${meta.id}.R1.trimmed.fastq.gz \
      -p ${meta.id}.R2.trimmed.fastq.gz \
      ${r1} ${r2} > ${meta.id}.cutadapt.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      cutadapt: \$(cutadapt --version)
    END_VERSIONS
    """
}
