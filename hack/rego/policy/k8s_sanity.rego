
package contract.pipelinerun.k8s_sanity

ok {
  denies := { m | m := deny[_] }
  count(denies) == 0
}

deny[msg] {
  data.k8s.PipelineRun[_].kind != "PipelineRun"
  msg := "Unexpected kind in PipelineRun data!"
}

deny[msg] {
  data.k8s.TaskRun[_].kind != "TaskRun"
  msg := "Unexpected kind in TaskRun data!"
}

deny[msg] {
  data.k8s.ConfigMap[_].kind != "ConfigMap"
  msg := "Unexpected kind in ConfigMap data!"
}
