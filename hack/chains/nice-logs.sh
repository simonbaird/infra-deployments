#!/bin/bash
#
# For viewing tekton chains logs
#
kubectl logs \
  -f --log-flush-frequency=1s --since=0 --tail=0 -l app=tekton-chains-controller -n tekton-chains |
    grep --line-buffered -v -E 'Reconcile succeeded|is still running' |
      jq -r '"\(.ts) \(.level) \(.msg)"'
      #jq '{ts: .ts, level: .level, msg: .msg}'
      #jq
