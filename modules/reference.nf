// Combined host + external-calibrator reference construction.
//
// The index is content-addressed, so a shared cache entry is reused whenever
// both source FASTAs and the Bowtie2 index format are unchanged. Without
// --combined_index_cache the same validated build runs in the work directory.

process build_combined_reference {
	label 'big_mem'
	module 'bowtie2/2.5.4'
	tag "combined reference"
	publishDir "${params.outdir}/manifests", mode: "copy", pattern: "reference_manifest.json"

	input:
	path host_fasta
	path external_fasta
	val cache_dir

	output:
	path "combined_index", emit: index
	path "reference_manifest.json", emit: manifest

	script:
	def cache_arg = cache_dir ? "--cache-dir ${cache_dir}" : "--output-dir combined_index"
	"""
	set -euo pipefail

	resolved=\$(build_combined_reference.py \\
		--host ${host_fasta} \\
		--external ${external_fasta} \\
		--threads ${task.cpus} \\
		${cache_arg})

	# Stage the resolved entry under a stable name. A cached entry is linked
	# rather than copied; an uncached build already lives at this path.
	if [ "\$resolved" != "\$PWD/combined_index" ]; then
		ln -s "\$resolved" combined_index
	fi

	cp -L combined_index/reference_manifest.json reference_manifest.json
	"""
}
