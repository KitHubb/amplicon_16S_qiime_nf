process FASTQC {
    tag "${meta.id}:${stage}"
    label 'process_low'
    container { params.fastqc_sif ?: (workflow.containerEngine == 'docker' ? 'quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0' : 'docker://quay.io/biocontainers/fastqc:0.12.1--hdfd78af_0') }

    publishDir { "${params.outdir}/${stage}/fastqc" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(r1), path(r2)
    val stage

    output:
    path '*_fastqc.zip',  emit: zip
    path '*_fastqc.html', emit: html
    path 'versions.yml',  emit: versions

    script:
    """
    fastqc --threads ${task.cpus} ${r1} ${r2}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      fastqc: \$(fastqc --version | sed 's/FastQC v//')
    END_VERSIONS
    """
}
