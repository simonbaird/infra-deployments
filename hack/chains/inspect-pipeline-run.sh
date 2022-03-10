#!/bin/bash

source $(dirname $0)/_helpers.sh
set -u

# Use a specific pipelinerun if provided, otherwise use the latest
PR_NAME=${1:-$( tkn pipelinerun describe --last -o name )}
PR_NAME=pipelinerun/$( trim-name $PR_NAME )

TR_NAMES=$(
  kubectl get $1 -o yaml | yq e '.status.taskRuns | keys | .[]' - )

for tr in $TR_NAMES; do
  title $tr
  kubectl get tr/$tr -o yaml | yq e '.metadata.annotations' -
done
