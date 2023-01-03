#!/usr/bin/env python

import os
import sys
from pyairtable.api.table import Table
from pyairtable.formulas import match

## COMMAND ARGS
EXP_TYPE    = sys.argv[1]
EXP_ID      = sys.argv[2]

## TABLE DEFINITIONS
api_key     = os.environ["AIRTABLE_API_KEY"]
base_id     = 'apptK6hzebfFE51gk' ## Raab-Lab base
exp_tbl     = 'tblHJz1fqya6s9azB' ## Experiments table
samp_tbl    = 'tbl9rCN4yiNDZA0Ww' ## Samples table
at          = Table(api_key=api_key, base_id=base_id, table_name=exp_tbl)

experiment = at.all(formula=match({"Name": EXP_ID}), fields = ["fldoakwuQUYDqWyaC", "fldcplZEsa9zDyTTp"])[0]

if (experiment['fields']['Experiment Type'] != EXP_TYPE):
    sys.exit("Incorrect experiment type for pipeline. Experiment must be " + EXP_TYPE)
else:
    print(experiment['fields']['Data Directory'], file=sys.stdout)
