#
# This is WIP.
# Just testing some basic rules and trying to learn rego.
#
# Todo:
# - How to return a message?
# - Fetch real attestation data
# - Fetch transparency log data
# - What about tekton results data?

package contract.pipelinerun.releaseable

import data.contract.pipelinerun.k8s_sanity

import future.keywords.every

default allow = false

allow = true {
  k8s_sanity.ok
  transparency_enabled
  #taskruns_marked_as_signed
}

# Transparency logs are enabled
# (Doesn't guarantee they were enabled when the pipeline ran though...)
transparency_enabled {
  data.k8s.ConfigMap["chains-config"].data["transparency.enabled"] == "true"
}

# All the trs are marked as signed
taskruns_marked_as_signed {
  every tr in data.k8s.TaskRun {
    tr.metadata.annotations["chains.tekton.dev/signed"] == "true"
  }
}
