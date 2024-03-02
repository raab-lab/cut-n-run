#!/usr/bin/env python

import os
import sys
from pyairtable import Api
from pyairtable.formulas import match

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

experiment = exp_tbl.all(formula=match({"Name": EXP_ID}), fields = ["fldoakwuQUYDqWyaC", "fldcplZEsa9zDyTTp"])[0]

if (experiment['fields']['Experiment Type'] != EXP_TYPE):
    sys.exit("Incorrect experiment type for pipeline. Experiment must be " + EXP_TYPE)
else:
    print(experiment['fields']['Data Directory'], file=sys.stdout)
