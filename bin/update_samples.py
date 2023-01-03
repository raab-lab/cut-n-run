#!/usr/bin/env python

import os
import sys
import csv
from pyairtable.api.table import Table
# from pyairtable.formulas import match

## COMMAND ARGS
SAMPLESHEET = sys.argv[1]

## TABLE DEFINITIONS
api_key     = os.environ["AIRTABLE_API_KEY"]
base_id     = 'apptK6hzebfFE51gk' ## Raab-Lab base
exp_tbl     = 'tblHJz1fqya6s9azB' ## Experiments table
samp_tbl    = 'tbl9rCN4yiNDZA0Ww' ## Samples table
at          = Table(api_key=api_key, base_id=base_id, table_name=samp_tbl)

## Create new records using the samplesheet
with open(sys.argv[1], encoding='utf-8') as csvf:
    csvReader = csv.DictReader(csvf)
    payload = [row for row in csvReader]
#print(payload)

at.batch_create(records=payload)


