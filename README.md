CUT&RUN
=======

A Nextflow DSL2 implementation of the Raab Lab CUT&RUN processing pipeline. Design modeled after the ![nf-core](https://nf-co.re/cutandrun) implementation.

In Nextflow, data flows through **channels** and into **processes**,
which transforms the data in some way and produces an output that can be passed to another process.
Processes are similar to functions.
Similar processes are grouped into **modules**, which can be invoked in the main script.

Modules and processes are then organized into **workflows**,
which is a set of processes and channels that constitute the pipeline.

Components
==========

## Tools to implement

- [X] Trim and FastQC
- [X] Alignment
- [ ] Cat/merge across lanes
- [X] Sort and index
- [X] Peak calling
- [X] Insert size QC
- [X] Remove duplicates
- [ ] Normalization factors
- [ ] Normalized coverage tracks
- [X] MultiQC report
