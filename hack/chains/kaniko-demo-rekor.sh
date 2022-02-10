#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $SCRIPTDIR/_helpers.sh
set -ue

# Use specific a taskrun if provided, otherwise use the most recent
TASKRUN_NAME=${1:-$( tkn tr describe --last -o name )}

# Let's not hard code the image url
IMAGE_URL=$( oc get $TASKRUN_NAME -o json | jq -r '.status.taskResults[1].value' )
IMAGE_REGISTRY=$( echo $IMAGE_URL | cut -d/ -f1 )

TRANSPARENCY_URL=$(
  oc get $TASKRUN_NAME -o jsonpath='{.metadata.annotations.chains\.tekton\.dev/transparency}' )

# Extract the log index from the url
LOG_INDEX=$( echo $TRANSPARENCY_URL | cut -d= -f2 )

# In the future we might use our own rekor servers, so let's not hard code that
REKOR_SERVER=$( echo $TRANSPARENCY_URL | cut -d/ -f1-3 )

title "Transparency url for $TASKRUN_NAME found in the annotations"
echo $TRANSPARENCY_URL
pause

title "Take a look at it"
curl-json $TRANSPARENCY_URL | yq e . -P -
pause

title "Using the rekor-cli"
show-then-run "rekor-cli get --log-index $LOG_INDEX --rekor_server $REKOR_SERVER"

title "There's also a --format json option:"
rekor-cli get --log-index $LOG_INDEX --rekor_server $REKOR_SERVER --format json | yq e . -P -
pause

title "Try a rekor-cli verify"
show-then-run "rekor-cli verify --log-index $LOG_INDEX --rekor_server $REKOR_SERVER"
