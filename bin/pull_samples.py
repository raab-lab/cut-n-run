#!/usr/bin/env python

import os
import sys
import csv
from pyairtable import Api
from pyairtable.formulas import match

## FIELD NAMES
field_names = ['SampleNumber', 'R1', 'R2', 'SampleID', 'Cell Line', 'Antibody', 'Treatment', 'Replicate']

## COMMAND ARGS
EXP_TYPE    = sys.argv[1]
EXP_ID      = sys.argv[2]

## TABLE DEFINITIONS
api_key     = os.environ["AIRTABLE_PAT"]
base_id     = 'apptK6hzebfFE51gk' ## Raab-Lab base
exp_tbl_id  = 'tblHJz1fqya6s9azB' ## Experiments table
samp_tbl_id = 'tbl9rCN4yiNDZA0Ww' ## Samples table

api = Api(api_key)

exp_tbl = api.table(base_id, exp_tbl_id)
samp_tbl = api.table(base_id, samp_tbl_id)

exp = exp_tbl.all(formula=match({"Name": EXP_ID}), fields = ["fldoakwuQUYDqWyaC", "fldcplZEsa9zDyTTp"])[0]

if(exp['fields']['Experiment Type'] != EXP_TYPE):
    sys.exit("Incorrect experiment type for pipeline. Experiment must be " + EXP_TYPE)

else:
    samples = samp_tbl.all(formula=match({"Experiment ID": EXP_ID }))
    with open("samplesheet.csv", 'w', newline='') as csvf:
        writer = csv.DictWriter(csvf, restval="NA", extrasaction='ignore', fieldnames=field_names)
        writer.writeheader()
        for samp in samples:
            writer.writerow(samp['fields'])
