#!/usr/bin/env python

import os
import sys
import csv
from pyairtable import Api

## COMMAND ARGS
SAMPLESHEET = sys.argv[1]

## TABLE DEFINITIONS
api_key     = os.environ["AIRTABLE_PAT"]
base_id     = 'apptK6hzebfFE51gk' ## Raab-Lab base
exp_tbl_id  = 'tblHJz1fqya6s9azB' ## Experiments table
samp_tbl_id = 'tbl9rCN4yiNDZA0Ww' ## Samples table

api = Api(api_key)
samp_tbl = api.table(base_id, samp_tbl_id)

## Create new records using the samplesheet
with open(sys.argv[1], encoding='utf-8') as csvf:
    csvReader = csv.DictReader(csvf)
    payload = [row for row in csvReader]
#print(payload)

samp_tbl.batch_create(records=payload)


