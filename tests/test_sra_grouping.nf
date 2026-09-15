// Exercises the run-grouping helper with real data.
//
// The DAG preview does not execute channel operators, so this ordering logic
// was only reached on the cluster. These assertions run locally in seconds.

include { merge_run_group } from '../subworkflows/sra_input'

workflow {
    // Two runs for one library, deliberately out of accession order.
    def two = merge_run_group(
        'S1',
        [[id: 'S1'], [id: 'S1']],
        ['SRR200', 'SRR100'],
        ['b_1.fq.gz', 'a_1.fq.gz'],
        ['b_2.fq.gz', 'a_2.fq.gz'])

    assert two[0].id == 'S1'
    assert two[1] == ['SRR100', 'SRR200'] : "runs not sorted: ${two[1]}"
    assert two[2] == ['a_1.fq.gz', 'b_1.fq.gz'] : "R1 not reordered with runs: ${two[2]}"
    assert two[3] == ['a_2.fq.gz', 'b_2.fq.gz'] : "R2 not reordered with runs: ${two[3]}"

    // A single-run sample takes the same path so filenames stay uniform.
    def one = merge_run_group('S2', [[id: 'S2']], ['SRR300'], ['x_1.fq.gz'], ['x_2.fq.gz'])
    assert one[1] == ['SRR300']
    assert one[2] == ['x_1.fq.gz']

    // Three runs, to catch any pairwise-only ordering mistake.
    def three = merge_run_group(
        'S3',
        [[id: 'S3'], [id: 'S3'], [id: 'S3']],
        ['SRR30', 'SRR10', 'SRR20'],
        ['c1', 'a1', 'b1'],
        ['c2', 'a2', 'b2'])
    assert three[1] == ['SRR10', 'SRR20', 'SRR30']
    assert three[2] == ['a1', 'b1', 'c1']
    assert three[3] == ['a2', 'b2', 'c2']

    println 'SRA run grouping OK'
}
