#!/bin/bash
#
# Based on https://github.com/tektoncd/chains/blob/main/docs/tutorials/getting-started-tutorial.md
#

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $SCRIPTDIR/_helpers.sh
set -ue

title "Suggested config for this demo:"
$SCRIPTDIR/config.sh simple --dry-run

title "Current config:"
$SCRIPTDIR/config.sh

title "Run a simple task and watch its logs"
kubectl create -f \
  https://raw.githubusercontent.com/tektoncd/chains/main/examples/taskruns/task-output-image.yaml
tkn tr logs --follow --last

#??
#?? The task produces a fake manifest json file with a digest that is
#?? visible to chains if oci storage is enabled, and I don't understand
#?? how or why.
#??

title "Wait a few seconds for chains finalizers to complete"
sleep 10

# Use this to show details about the taskrun and cosign verify it
$SCRIPTDIR/check-taskrun.sh
