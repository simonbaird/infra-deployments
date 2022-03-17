#!/bin/bash -ue

DEFAULT_URL=quay.io/sbaird/chains-demo
IMAGE_URL=${1:-$DEFAULT_URL}

# First find the digest of the image
IMAGE_DIGEST=$( skopeo inspect --no-tags docker://$IMAGE_URL | jq -r .Digest )

# Use the digest to do a rekor lookup
UUIDS=$( rekor-cli search --sha "$IMAGE_DIGEST" 2>/dev/null )

# There might be more than one so loop over them
for uuid in $UUIDS; do
  # Fetch the rekor data
  REKOR_DATA=$( rekor-cli get --uuid $uuid --format json )

  # Show some output
  echo '---'
  echo "$REKOR_DATA" | jq -r .Attestation | base64 -d | yq e -P -
done
