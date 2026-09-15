include { DADA2_TRIMM_SWEEP; TAXONOMY_TRIMM_SWEEP; SELECT_TRIMM_OPTIMAL } from '../modules/trimm_optimal'

workflow TRIMM_OPTIMAL_WORKFLOW {
    take:
    demux
    classifier
    taxonomy_label

    main:
    combinations_file = params.trimm_combinations ?: "${projectDir}/params/trimming/${params.region.toString().trim().toLowerCase()}_10bp.tsv"
    log.info "Truncation candidates: ${combinations_file}"
    combinations = Channel
        .fromPath(combinations_file, checkIfExists: true)
        .splitCsv(header: true, sep: '\t', strip: true)
        .map { row ->
            def name = row.name.toString()
            def truncF = row.trunc_len_f as Integer
            def truncR = row.trunc_len_r as Integer
            if (truncF <= truncR) {
                error "Invalid trimm combination '${name}': trunc_len_f (${truncF}) must be greater than trunc_len_r (${truncR})"
            }
            if ((truncF % 10) != 0 || (truncR % 10) != 0) {
                error "Invalid trimm combination '${name}': both lengths must use 10-nt increments"
            }
            tuple(name, truncF, truncR)
        }

    sweep_input = combinations
        .combine(demux)
        .map { opt_id, trunc_f, trunc_r, demux_qza -> tuple(opt_id, trunc_f, trunc_r, demux_qza) }

    DADA2_TRIMM_SWEEP(sweep_input)
    TAXONOMY_TRIMM_SWEEP(DADA2_TRIMM_SWEEP.out.results, classifier, taxonomy_label)

    candidate_files = TAXONOMY_TRIMM_SWEEP.out.evaluated
        .flatMap { db, opt_id, trunc_f, trunc_r, table, repseq, stats, taxonomy, metrics ->
            [table, repseq, stats, taxonomy, metrics]
        }
        .collect()

    SELECT_TRIMM_OPTIMAL(taxonomy_label, candidate_files)

    emit:
    table           = SELECT_TRIMM_OPTIMAL.out.table
    repseq          = SELECT_TRIMM_OPTIMAL.out.repseq
    stats           = SELECT_TRIMM_OPTIMAL.out.stats
    selection       = SELECT_TRIMM_OPTIMAL.out.selection
    comparison      = SELECT_TRIMM_OPTIMAL.out.comparison
    selected_params = SELECT_TRIMM_OPTIMAL.out.selected_params
}
