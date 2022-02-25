#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Use a specific taskrun if provided, otherwise use the latest
TASKRUN_NAME=${1:-$( tkn taskrun describe --last -o name )}
TASKRUN_NAME=taskrun/$( echo $TASKRUN_NAME | sed 's#.*/##' )

QUIET_OPT=$2
SIG_KEY=$COSIGN_SIG_KEY

# Preserve sanity while hacking
set -ue

if [[ $QUIET_OPT == "--quiet" ]]; then
  ECHO=:
  QUIET=1
else
  ECHO=echo
  QUIET=
fi

title() {
  $ECHO
  $ECHO "🔗 ---- $* ----"
}

pause() {
  [[ -n $QUIET ]] && return
  read -p "Hit enter continue"
}

# Helper for jsonpath
get-jsonpath() {
  kubectl get $TASKRUN_NAME -o jsonpath={.$1}
}

# Helper for reading chains values
get-chainsval() {
  get-jsonpath metadata.annotations.chains\\.tekton\\.dev/$1
}

# Helper for reading a task result
get-taskresult() {
  kubectl get $TASKRUN_NAME \
    -o jsonpath="{.status.taskResults[?(@.name == \"$1\")].value}"
}

# Fetch task run signature and payload
TASKRUN_UID=$( get-jsonpath metadata.uid )
SIGNATURE=$( get-chainsval signature-taskrun-$TASKRUN_UID )
PAYLOAD=$( get-chainsval payload-taskrun-$TASKRUN_UID | base64 --decode )

IMAGE_DIGEST=$( get-taskresult IMAGE_DIGEST )
if [[ -n $IMAGE_DIGEST ]]; then
  SHORT_IMAGE_DIGEST=$( get-taskresult IMAGE_DIGEST | cut -d: -f2 | head -c 12 )
  IMAGE_SIGNATURE=$( get-chainsval signature-$SHORT_IMAGE_DIGEST )
  IMAGE_PAYLOAD=$( get-chainsval payload-$SHORT_IMAGE_DIGEST | base64 --decode)

  # Todo: Do something with these, or create a separate
  # check-taskrun-image.sh to verify image signatures
  #echo $IMAGE_DIGEST
fi

# Try to detect and then handle different formats
# (It seems like it would be better if the format was available
# explicitly but afaict it is not.)

# If the signature is 96 chars then we might be using tekton format
if [[ ${#SIGNATURE} == 96 ]]; then
  title "Assuming tekton format"
  # The signature is just the signature, continue

else
  title "Assuming in-toto format"

  # The signature value is actually encoded json with a payload and
  # signature list inside it
  SIG_DATA=$( echo $SIGNATURE | base64 --decode )
  SIGNATURE=$( echo $SIG_DATA | jq -r '.signatures[0].sig' )

  # No idea why the same payload can be found in both places...
  OTHER_PAYLOAD=$( echo $SIG_DATA | jq -r .payload | base64 --decode )

  if [[ "$PAYLOAD" != "$OTHER_PAYLOAD" ]]; then
    # Seems like we'll never get here
    echo "The two payloads are unexpectedly different!"
    exit 1
  fi

fi

# Cosign wants files on disk afaict
SIG_FILE=$( mktemp )
PAYLOAD_FILE=$( mktemp )
echo -n "$PAYLOAD" > $PAYLOAD_FILE
echo -n "$SIGNATURE" > $SIG_FILE

if [[ -z $SIG_KEY ]]; then
  # Requires that you're authenticated with an account that can access
  # the signing-secret, i.e. kubeadmin but not developer
  SIG_KEY=k8s://tekton-chains/signing-secrets

  # If you have the public key locally because you created it
  # (Presumably real public keys can be published somewhere in future)
  #SIG_KEY=$SCRIPTDIR/../../cosign.pub
fi

# Show details about this taskrun
title Taskrun name
$ECHO $TASKRUN_NAME

title Signature
$ECHO $SIGNATURE

pause

title Payload
#[[ -z $QUIET ]] && echo "$PAYLOAD" | jq
[[ -z $QUIET ]] && echo "$PAYLOAD" | yq e -P -

pause

# Keep going if the verify fails
set +e

## Fixme: This only works with artifacts.taskrun.format set to 'tekton'.
## I've never been able to use cosign verify-blob to verify a task's
## payload and signature using the 'in-toto' format and I don't know why.

# Now use cosign to verify the signed payload
title Verification
[[ -z $QUIET ]] && set -x
cosign verify-blob --key $SIG_KEY --signature $SIG_FILE $PAYLOAD_FILE
COSIGN_EXIT_CODE=$?
set +x

title "For debugging"
$ECHO "env EDITOR=view oc edit $TASKRUN_NAME"

# Clean up
rm $SIG_FILE $PAYLOAD_FILE

# Use the exit code from cosign
exit $COSIGN_EXIT_CODE
