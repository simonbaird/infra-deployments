#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

OPA_DATA_DIR=$(dirname $0)/data
OPA_POLICY_DIR=$(dirname $0)/policy

opa eval \
  --data $OPA_DATA_DIR \
  --data $OPA_POLICY_DIR \
  --format=pretty \
  data.contract.pipelinerun.releaseable.allow
