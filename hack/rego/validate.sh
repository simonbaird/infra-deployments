#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

OPA_DATA_DIR=$(dirname $0)/data
OPA_POLICY=$(dirname $0)/policy.rego

opa eval \
  --data $OPA_DATA_DIR \
  --data $OPA_POLICY \
  --format=pretty \
  data.contract.pipelinerun.releaseable.allow
