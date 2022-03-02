#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $SCRIPTDIR/_helpers.sh
set -e

echo "To watch the chains controller logs:"
echo "  kubectl logs -f -l app=tekton-chains-controller -n tekton-chains | sed G"
echo "or:"
echo "  hack/chains/nice-logs.sh"
pause

title "Set project"
# It shouldn't matter, but let's make sure it works without being in
# tekton-chains project or whatever
oc project default

if [[ -z "$QUAY_SECRET_NAME" ]]; then
  echo "Please set environment variable QUAY_SECRET_NAME and try again!"
  echo "For example: export QUAY_SECRET_NAME=sbaird-chains-demo-pull-secret"
  exit 1
fi

if [[ -z "$QUAY_IMAGE" ]]; then
  echo "Please set environment variable QUAY_IMAGE and try again!"
  echo "For example: export QUAY_IMAGE=quay.io/sbaird/chains-demo"
  exit 1
fi

if ! kubectl get secret/$QUAY_SECRET_NAME -o name; then
  echo "Can't find $QUAY_SECRET_NAME!" &&
  echo "Please ensure it exists and try again!" &&
  echo "For example: kubectl apply -f sbaird-chains-demo-secret.yml"
  exit 1
fi

# Ensure we have the cluster task and pipeline ready for this demo
kubectl apply -f $SCRIPTDIR/pipeline-quay-demo.yaml

# Run the pipeline
tkn pipeline start \
  --param IMAGE="$QUAY_IMAGE" \
  --param PUSH_SECRET_NAME="$QUAY_SECRET_NAME" \
  --showlog \
  -w name=source,pvc,claimName="ci-builds" \
  chains-demo-pipeline
