#
# This is WIP.
# Just testing some basic rules and trying to learn rego.
#
# Todo:
# - How to return a message?
# - How to not need to list each check in the allow block
# - How to do a "fail when" instead of "pass when" style

package contract.pipelinerun.releaseable

import future.keywords.every

default allow = false

allow = true {
  pipelinerun_sanity_check
  taskrun_sanity_check
  transparency_enabled
  #taskruns_marked_as_signed
}

# All the prs have the expected kind
pipelinerun_sanity_check {
  every pr in data.k8s.PipelineRun {
    pr.kind == "PipelineRun"
  }
}

# All the trs have the expected kind
taskrun_sanity_check {
  every tr in data.k8s.TaskRun{
    tr.kind == "TaskRun"
  }
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
