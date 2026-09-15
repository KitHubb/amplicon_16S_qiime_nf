nextflow.enable.dsl = 2

include { CUTADAPT } from '../modules/cutadapt'

workflow {
    def legacy = PrimerConfig.resolve([:])
    assert legacy.primer_f == 'AGAGTTTGATCCTGGCTCAG'
    assert legacy.primer_r == 'ATTACCGCGGCTGCTGG'
    assert legacy.adapter_f == 'CCAGCAGCCGCGGTAAT'
    assert legacy.adapter_r == 'CTGAGCCAGGATCAAACTCT'
    def v34 = PrimerConfig.resolve([region: 'v3v4'])
    assert v34.primer_f == 'CCTACGGGNGGCWGCAG'
    assert v34.primer_r == 'GACTACHVGGGTATCTAATCC'
    assert v34.adapter_f == 'GGATTAGATACCCBDGTAGTC'
    assert v34.adapter_r == 'CTGCWGCCNCCCGTAGG'
    def custom = PrimerConfig.resolve([region: 'V3V4', primer_f: 'acgtry'])
    assert custom.primer_f == 'ACGTRY'
    assert custom.primer_r == v34.primer_r
    assert custom.adapter_r == 'RYACGT'
    assert PrimerConfig.resolve([primer_r: 'AACCGG']).adapter_f == 'CCGGTT'
    assert PrimerConfig.resolve([adapter_f: 'AAAA', adapter_r: 'CCCC']).adapter_r == 'CCCC'
    assert PrimerConfig.resolve([adapter_f: 'AAAA']).adapter_f == 'AAAA'
    [[region: 'V4'], [primer_f: ''], [primer_r: 'ACGT!'], [adapter_f: 'A;X']].each { bad ->
        boolean rejected = false
        try { PrimerConfig.resolve(bad) } catch (IllegalArgumentException e) { rejected = true }
        assert rejected
    }
    def selected = PrimerConfig.resolve(params)
    assert selected.region == 'V3V4'
    assert selected.primer_f == 'ACGTACGTACGT'
    assert selected.primer_r == v34.primer_r
    log.info 'Primer assertions and YAML/CLI precedence passed'
    CUTADAPT(Channel.of(tuple([id: 'synthetic'], file(params.test_r1), file(params.test_r2))), Channel.value(selected))
}
