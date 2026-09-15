class PrimerConfig {
    static String sequence(Object value, String name) {
        String result = value.toString().trim().toUpperCase()
        if (!(result ==~ /[ACGTRYSWKMBDHVN]+/)) {
            throw new IllegalArgumentException("${name} must be a non-empty IUPAC DNA sequence")
        }
        return result
    }

    static String reverseComplement(String sequence) {
        String bases = 'ACGTRYSWKMBDHVN'
        String complements = 'TGCAYRSWMKVHDBN'
        return sequence.reverse().collect { complements[bases.indexOf(it.toString())] }.join('')
    }

    static Map resolve(Map options) {
        String region = (options.region != null ? options.region : 'V1V3').toString().trim().toUpperCase()
        Map defaults = [
            V1V3: [primer_f: 'AGAGTTTGATCCTGGCTCAG', primer_r: 'ATTACCGCGGCTGCTGG'],
            V3V4: [primer_f: 'CCTACGGGNGGCWGCAG', primer_r: 'GACTACHVGGGTATCTAATCC']
        ]
        if (!defaults.containsKey(region)) {
            throw new IllegalArgumentException("Unknown region '${region}'; choose V1V3 or V3V4")
        }
        Map result = [region: region]
        ['primer_f', 'primer_r'].each { key ->
            result[key] = sequence(options[key] != null ? options[key] : defaults[region][key], key)
        }
        result.adapter_f = options.adapter_f != null ? sequence(options.adapter_f, 'adapter_f') : reverseComplement(result.primer_r)
        // Preserve the historical V1V3 reverse read-through sequence exactly.
        result.adapter_r = options.adapter_r != null ? sequence(options.adapter_r, 'adapter_r') :
            (region == 'V1V3' && result.primer_f == defaults.V1V3.primer_f ?
                'CTGAGCCAGGATCAAACTCT' : reverseComplement(result.primer_f))
        return result
    }
}
