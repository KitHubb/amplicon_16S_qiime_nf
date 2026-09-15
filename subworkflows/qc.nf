include { FASTQC } from '../modules/fastqc'
include { MULTIQC } from '../modules/multiqc'

workflow QC {
    take:
    reads
    stage

    main:
    FASTQC(reads, stage)
    MULTIQC(FASTQC.out.zip.collect(), stage)

    emit:
    report = MULTIQC.out.report
}
