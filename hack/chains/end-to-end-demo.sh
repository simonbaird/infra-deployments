#!/bin/bash
#
# A demo script that runs a build pipeline including HACBS specific tests and a sample release pipeline with HACBS Enterprise Contract test

APP_GIT_REPOSITORY=https://github.com/jduimovich/single-nodejs-app
APP_BUILDER=nodejs-builder
APP_IMAGE_NAME="${APP_GIT_REPOSITORY/*\/}"
APP_IMAGE_REF="quay.io/${MY_QUAY_USER}/${APP_IMAGE_NAME}"

# Check for $MY_QUAY_USER
if [[ -z ${MY_QUAY_USER+x} ]]; then
  echo "🛑 Make sure to set the \$MY_QUAY_USER environment variable, it needs to be set to the
   Quay.io organization where the resulting images will be pushed"
  exit 1
fi

set -euo pipefail

(
  while :
  do
    for i in {0..11}; do
      printf "\r\xf0\x9f\x95\x$(printf %x $((144 + i))) Folding space..."
      sleep 0.3
    done
  done
) &

CLOCKY=$!
stop_clocky() {
  printf "\r                                                            "
  kill ${CLOCKY} 2>/dev/null 1>&2 || true
}

trap stop_clocky EXIT

DOCKER_LOGIN=$(docker login quay.io </dev/null 2>&1 || true)
if [[ "${DOCKER_LOGIN}" != *"Login Succeeded"* ]]; then
  stop_clocky
  echo "ℹ️  Please enter the quay.io credentials for ${MY_QUAY_USER}"
  docker login quay.io --username "${MY_QUAY_USER}"
fi

# Making sure that the quay.io repository exists, this is to help with the check below.
# We create an essentially empty image, push it and delete it afterwards, the net result
# being that the registry exists and it's visibility can be changed to public
(
  cd "$(mktemp -d)"
  echo 'FROM scratch
LABEL org.opencontainers.image.authors="Mister Mxyzptlk"' > Dockerfile
  docker build -q -t "${APP_IMAGE_REF}:bogus" . 2>/dev/null 1>&2
  docker push -q "${APP_IMAGE_REF}:bogus" 2>/dev/null 1>&2
  skopeo delete docker://"${APP_IMAGE_REF}:bogus"
  rm -rf "${PWD}"
)

# Making the quay.io repository public, this is a requirement right now for the Test stream tasks to succeed
if [[ "$(curl -s "https://quay.io/api/v1/repository?namespace=${MY_QUAY_USER}&public=true" | jq ".repositories[] | select(.name==\"${APP_IMAGE_NAME}\") | has(\"name\")")" != 'true' ]]; then
  stop_clocky
  echo "🛑 Make sure that the quay.io repository is public, change the visibility here:
👉 https://quay.io/repository/${MY_QUAY_USER}/${APP_IMAGE_NAME}?tab=settings "
  exit 1
fi

# We're going to assume running with kubeadmin
if [[ "$(kubectl auth can-i '*' '*' < /dev/null 2>&1)" != 'yes' ]]; then
  stop_clocky
  echo "🛑 Make sure that you're logged in as kubeadmin, we make assumptions here"
  exit 1
fi

# Checking the status of the build component as a way to make sure that the cluster is okay to run the demo
if [[ "$(kubectl get -n openshift-gitops applications.argoproj.io build -o jsonpath='{.status.sync.status}')" != 'Synced' ]]; then
  stop_clocky
  echo "🛑 Make sure that the cluster is setup by running hack/bootstrap-cluster.sh first see
👉 https://github.com/redhat-appstudio/infra-deployments#bootstrapping-a-cluster"
  exit 1
fi

stop_clocky

echo "📜 The outline of the demo
  1. We'll start a build pipeline using build-definitions/hack/test-build.sh
     to build a Node.js app. This will include running the sanity checks from
     the Test stream and gathering attestations and signatures from the
     Contract team.
  2. Next, a sample release pipeline will be run that will check the results
     from the build pipeline and copy the image to the production environment.

We'll show the commands being run, and point to data or visualisations.
"

HACK_CHAINS_DIR="$(dirname "$0")"

BUILD_DEFINITIONS_DIR="${HACK_CHAINS_DIR}/../../../build-definitions"
if [[ ! -d "${BUILD_DEFINITIONS_DIR}" ]]; then
  echo "ℹ️  Did not find redhat-appstudio/build-definitions clone in ${BUILD_DEFINITIONS_DIR}, using upstream version"
  BUILD_DEFINITIONS_DIR="$(mktemp -d build-definitions.XXXXXXXXXX)"
  trap "rm -rf ${BUILD_DEFINITIONS_DIR}" EXIT
  (cd "${BUILD_DEFINITIONS_DIR}" && curl -sLO https://github.com/redhat-appstudio/build-definitions/archive/refs/heads/main.zip && unzip main.zip && mv build-definitions-main/* . && rm main.zip)
fi

{
  oc project demo 2>/dev/null 1>&2 && echo -n "ℹ️  Using existing 'demo' OpenShift project"
} || {
  echo "📂 Creating a new OpenShift project 'demo'
"
  oc new-project demo
}
echo "Here is the OpenShift console with the project:

👉 $(oc whoami --show-console)/k8s/cluster/projects/demo
"

echo "♾️  Setting up pipelines
"
kubectl apply -k "${BUILD_DEFINITIONS_DIR}/hack/test-build"
kubectl apply -k "${BUILD_DEFINITIONS_DIR}/pipelines/hacbs"

# This is for the build pipeline
kubectl create secret docker-registry redhat-appstudio-staginguser-pull-secret --from-file=.dockerconfigjson="${HOME}/.docker/config.json" --dry-run=client -o yaml | kubectl apply -f -

# This is for the chains-controller
kubectl create secret docker-registry quay-pull-secret --from-file=.dockerconfigjson="${HOME}/.docker/config.json" -n tekton-chains --dry-run=client -o yaml | kubectl apply -f -
kubectl patch sa pipeline -n tekton-chains -p '{"imagePullSecrets": [{"name": "quay-pull-secret"}]}'

echo "
🏃 Running a build pipeline

💲 build-definitions/hack/test-build.sh ${APP_GIT_REPOSITORY} ${APP_BUILDER}
"
# see https://serverfault.com/a/989827
{ BUILD_PIPELINE_RUN=$("${BUILD_DEFINITIONS_DIR}/hack/test-build.sh" "${APP_GIT_REPOSITORY}" "${APP_BUILDER}" | tee /dev/fd/3 | grep 'PipelineRun started: ' | sed -e 's/PipelineRun started: //'); } 3<&1
tkn pipelinerun logs --follow "${BUILD_PIPELINE_RUN}"
BUILD_OUTPUT_IMAGE_REF=$(tkn pipelinerun describe "${BUILD_PIPELINE_RUN}" -o jsonpath='{.spec.params[?(@.name=="output-image")].value}')

echo "
ℹ️  Build pipeline finished

Make note that some of the steps could have been skipped over because of the
pipeline caching.

Here is the pipeline visualisation:

👉 $(oc whoami --show-console)/k8s/ns/demo/tekton.dev~v1beta1~PipelineRun/${BUILD_PIPELINE_RUN}
"

RELEASE_OUTPUT_IMAGE_REF="${BUILD_OUTPUT_IMAGE_REF%:*}:production"

echo "
🏃 Running a sample release pipeline (to demo Enterprise Contract task)

💲 infra-deployments/hack/chains/release-pipeline-with-ec-demo.sh" "${BUILD_OUTPUT_IMAGE_REF}" "${RELEASE_OUTPUT_IMAGE_REF}
"
kubectl create secret docker-registry release-demo --from-file=.dockerconfigjson="${HOME}/.docker/config.json" --dry-run=client -o yaml | kubectl apply -f -
oc secrets link pipeline release-demo --for=pull,mount
"${HACK_CHAINS_DIR}/copy-public-sig-key.sh"
TASK_BUNDLE=quay.io/redhat-appstudio/appstudio-tasks:$(git ls-remote --heads https://github.com/redhat-appstudio/build-definitions.git refs/heads/main|cut -f 1)-2
export TASK_BUNDLE
# For simplicity tag with `production`
"${HACK_CHAINS_DIR}/release-pipeline-with-ec-demo.sh" "${BUILD_OUTPUT_IMAGE_REF}" "${RELEASE_OUTPUT_IMAGE_REF}"
