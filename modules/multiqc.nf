process MULTIQC {
    tag stage
    label 'process_low'
    container { params.qc_sif ?: (workflow.containerEngine == 'docker' ? 'quay.io/biocontainers/multiqc:1.27--pyhdfd78af_0' : 'docker://quay.io/biocontainers/multiqc:1.27--pyhdfd78af_0') }

    publishDir { "${params.outdir}/${stage}/multiqc" }, mode: 'copy', overwrite: true

    input:
    path fastqc_zips
    val stage

    output:
    path 'multiqc_report.html', emit: report
    path 'multiqc_report_data', emit: data
    path 'versions.yml',        emit: versions

    script:
    """
    multiqc --force --filename multiqc_report.html .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      multiqc: \$(multiqc --version | awk '{print \$NF}')
    END_VERSIONS
    """
}
