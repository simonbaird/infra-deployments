#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#
# OPA will use the dir names as keys, so this produces a structure like this:
#
#   PipelineRun:
#     <pr-name>
#       ...
#   TaskRun:
#     <tr-1-name>
#       ...
#     <tr-2-name>
#       ...
#     ...
#   ConfigMap:
#     chains-config
#
# Notice there are no lists. It might be nicer the task runs were in a list rather
# than a dict but lets see how it goes.
#

DATA_DIR=$(dirname $0)/data

# Clean out old data
rm -rf $DATA_DIR

# Find the pipeline run we want to validate
PR_NAME=${1:-$( tkn pr describe --last -o name )}
PR_NAME=$( echo $PR_NAME | sed 's#.*/##' )

# Find the pipelinerun's taskruns
TR_NAMES=$(
  kubectl get pr/$PR_NAME -o json | jq -r '.status.taskRuns|keys|.[]' )

# A helper for saving a kubernetes object to the data dir
save-to-file() {
  local type=$1
  local name=$2
  local name_space=${3:-}

  local name_space_opt=
  [[ -n $name_space ]] && name_space_opt="-n$name_space"

  OBJECT_DIR="$DATA_DIR/k8s/$type"
  OBJECT_FILE="$OBJECT_DIR/$name.yaml"

  mkdir -p $OBJECT_DIR

  # Todo: we might need name_space the path to avoid clashes
  [[ -f $OBJECT_FILE ]] && echo "Name clash for $OBJECT_FILE!" && exit 1

  # OPA will try to merge everything so inject the name as a top level key
  kubectl get $name_space_opt $type $name -o yaml | yq e "{\"$2\": .}" -P - > $OBJECT_FILE
}

# Write data
save-to-file ConfigMap chains-config tekton-chains
save-to-file PipelineRun $PR_NAME
for tr in $TR_NAMES; do
  save-to-file TaskRun $tr
done

# Show what we created
find data -name *.yaml
