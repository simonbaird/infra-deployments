Enterprise Contract Experiments with OPA and Rego
=================================================

Not sure if this will get merged, but I'm pushing early and often to share the
ideas and concepts, and to encourage collaboration.

Working so far
--------------

* A POC that showing how to write a rego policy and use it to validate
  aspects of a pipeline run.

Still to do
-----------

* More useful and realistic policies
* Run the whole thing in a task and expose the validation results in the task output
* Pull down data from other sources, not just the cluster, and use that data in
  policy rules
