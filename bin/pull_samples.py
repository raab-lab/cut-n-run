#!/usr/bin/env python

import os
import sys
import csv
from pyairtable.api.base import Base
from pyairtable.formulas import match

## FIELD NAMES
field_names = ['R1', 'R2', 'SampleID', 'Cell Line', 'Antibody', 'Treatment', 'Replicate']

## COMMAND ARGS
EXP_TYPE    = sys.argv[1]
EXP_ID      = sys.argv[2]

## TABLE DEFINITIONS
api_key     = os.environ["AIRTABLE_API_KEY"]
base_id     = 'apptK6hzebfFE51gk' ## Raab-Lab base
exp_tbl     = 'tblHJz1fqya6s9azB' ## Experiments table
samp_tbl    = 'tbl9rCN4yiNDZA0Ww' ## Samples table
at          = Base(api_key=api_key, base_id=base_id)

experiment = at.all(table_name=exp_tbl,formula=match({"Name": EXP_ID}), fields = ["fldoakwuQUYDqWyaC", "fldcplZEsa9zDyTTp"])[0]
if(experiment['fields']['Experiment Type'] != EXP_TYPE):
    sys.exit("Incorrect experiment type for pipeline. Experiment must be " + EXP_TYPE)
else:

    samples = at.all(table_name=samp_tbl,formula=match({"Experiment ID": EXP_ID }))
    with open("samplesheet.csv", 'w', newline='') as csvf:
        writer = csv.DictWriter(csvf, restval="NA", extrasaction='ignore', fieldnames=field_names)
        writer.writeheader()
        for samp in samples:
            writer.writerow(samp['fields'])



