nextflow.enable.dsl = 2

params.reads = null
params.outdir = 'results'

include { QC as RAW_QC; QC as CLEAN_QC } from './subworkflows/qc'
include { CUTADAPT } from './modules/cutadapt'
include { QIIME_IMPORT } from './modules/qiime_import'
include { QIIME_DADA2 } from './modules/qiime_dada2'
include { QIIME_TAXONOMY } from './modules/qiime_taxonomy'
include { QIIME_PHYLOGENY } from './modules/qiime_phylogeny'
include { QIIME_DIVERSITY } from './modules/qiime_diversity'
include { TRIMM_OPTIMAL_WORKFLOW } from './subworkflows/trimm_optimal'

workflow {
    primers = PrimerConfig.resolve(params)
    log.info "Region: ${primers.region}; primer_f: ${primers.primer_f}; primer_r: ${primers.primer_r}; adapter_f: ${primers.adapter_f}; adapter_r: ${primers.adapter_r}"
    if (!params.reads) {
        error 'Provide --reads, e.g. /data/run/*_{1,2}.fastq.gz'
    }
    if (!params.metadata) {
        error 'Provide --metadata with a QIIME 2-compatible TSV file'
    }

    if (!params.classifier) {
        error 'Provide --classifier with a QIIME 2 classifier artifact'
    }

    reads_ch = Channel
        .fromFilePairs(params.reads, checkIfExists: true, flat: true)
        .map { id, r1, r2 -> tuple([id: id.toString(), single_end: false], r1, r2) }

    // 1. Raw-read FastQC and MultiQC.
    RAW_QC(reads_ch, '01_raw_qc')

    // 2. Region-selected primer removal and quality trimming.
    CUTADAPT(reads_ch, Channel.value(primers))

    // 3. FastQC and MultiQC after Cutadapt.
    CLEAN_QC(CUTADAPT.out.reads, '03_clean_qc')

    // 4. Collect all cleaned FASTQ files and import as paired-end QIIME data.
    clean_fastqs_ch = CUTADAPT.out.reads
        .flatMap { meta, r1, r2 -> [r1, r2] }
        .collect()

    QIIME_IMPORT(clean_fastqs_ch)

    metadata_ch = Channel.value(file(params.metadata, checkIfExists: true))
    classifier_file = file(params.classifier, checkIfExists: true)
    classifier_ch = Channel.value(classifier_file)

    taxonomy_label = params.taxonomy_label?.toString()?.trim()
    if (!taxonomy_label || taxonomy_label.equalsIgnoreCase('AUTO')) {
        classifier_path_lower = classifier_file.toString().toLowerCase()
        taxonomy_label = classifier_path_lower.contains('/gg2/')   ? 'GG2'   :
                         classifier_path_lower.contains('/silva/') ? 'SILVA' :
                         classifier_path_lower.contains('/gtdb')   ? 'GTDB'  :
                         classifier_file.baseName
    }
    taxonomy_label = taxonomy_label.replaceAll(/[^A-Za-z0-9._-]/, '_')
    taxonomy_label_ch = Channel.value(taxonomy_label)

    // 5. Standard DADA2, or optional parameter sweep followed by rule-based selection.
    if (params.trimm_optimal.toString().toBoolean()) {
        TRIMM_OPTIMAL_WORKFLOW(QIIME_IMPORT.out.demux, classifier_ch, taxonomy_label_ch)
        selected_table_ch = TRIMM_OPTIMAL_WORKFLOW.out.table
        selected_repseq_ch = TRIMM_OPTIMAL_WORKFLOW.out.repseq
    } else {
        QIIME_DADA2(QIIME_IMPORT.out.demux)
        selected_table_ch = QIIME_DADA2.out.table
        selected_repseq_ch = QIIME_DADA2.out.repseq
    }

    // 6. Final SILVA taxonomy assignment and taxa bar plot using the selected ASVs.
    QIIME_TAXONOMY(
        selected_repseq_ch,
        selected_table_ch,
        metadata_ch,
        classifier_ch,
        taxonomy_label_ch
    )

    // 7. MAFFT alignment, masking, FastTree and midpoint-rooted phylogeny.
    QIIME_PHYLOGENY(selected_repseq_ch)

    // 8. Optional phylogenetic alpha/beta diversity, rarefaction, PCoA and Emperor plots.
    if (params.diversity_enabled.toString().toBoolean()) {
        QIIME_DIVERSITY(
            selected_table_ch,
            QIIME_PHYLOGENY.out.rooted_tree,
            metadata_ch
        )
    }
}
