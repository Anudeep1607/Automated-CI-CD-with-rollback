#!/usr/bin/env bash
# Local training helper: deploy, verify, and roll back if release health fails.
set -uo pipefail
APP_NAME="${APP_NAME:-demo-app}"
NAMESPACE="${NAMESPACE:-devops-demo}"
IMAGE_NAME="${IMAGE_NAME:-demo-app}"
IMAGE_TAG="${IMAGE_TAG:-1}"
HELM_CHART="${HELM_CHART:-helm/demo-app}"
SIMULATE_BAD_RELEASE="${SIMULATE_BAD_RELEASE:-false}"
HELM_TIMEOUT="${HELM_TIMEOUT:-60s}"
SMOKE_PORT="${SMOKE_PORT:-18080}"
mkdir -p .artifacts

previous_revision="$(helm history "${APP_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null |
  python3 -c 'import json,sys
try:
 rows=json.load(sys.stdin)
 rev=[int(x["revision"]) for x in rows if x.get("status","").lower()=="deployed"]
 print(max(rev) if rev else "")
except Exception: print("")' 2>/dev/null)"
previous_revision="${previous_revision//$'\n'/}"
echo "Previous deployed revision: ${previous_revision:-none}"
echo "Deploying ${IMAGE_NAME}:${IMAGE_TAG}; simulate unhealthy=${SIMULATE_BAD_RELEASE}"

set +e
helm upgrade --install "${APP_NAME}" "${HELM_CHART}" \
  --namespace "${NAMESPACE}" --create-namespace --wait --timeout "${HELM_TIMEOUT}" \
  --set-string image.repository="${IMAGE_NAME}" \
  --set-string image.tag="${IMAGE_TAG}" \
  --set-string image.pullPolicy="Never" \
  --set-string app.unhealthy="${SIMULATE_BAD_RELEASE}"
deploy_status=$?
set -e

smoke_test() {
  local log_file=".artifacts/port-forward.log"
  kubectl port-forward "service/${APP_NAME}" "${SMOKE_PORT}:5000" -n "${NAMESPACE}" >"${log_file}" 2>&1 &
  local pf_pid=$!
  local attempt
  for attempt in $(seq 1 20); do
    if curl --silent --show-error --fail "http://127.0.0.1:${SMOKE_PORT}/health"; then
      echo
      kill "${pf_pid}" >/dev/null 2>&1 || true
      wait "${pf_pid}" 2>/dev/null || true
      return 0
    fi
    sleep 1
  done
  echo "Smoke test failed. Port-forward log:"
  cat "${log_file}" || true
  kill "${pf_pid}" >/dev/null 2>&1 || true
  wait "${pf_pid}" 2>/dev/null || true
  return 1
}

if [ "${deploy_status}" -eq 0 ]; then
  echo "Helm rollout completed. Running smoke test..."
  if smoke_test; then
    echo "Deployment and smoke test succeeded."
    exit 0
  fi
  deploy_status=1
else
  echo "Helm deployment failed; beginning recovery."
fi

echo "Deployment verification failed. Attempting recovery..."
if [ -n "${previous_revision}" ]; then
  echo "Rolling back ${APP_NAME} to revision ${previous_revision}..."
  if helm rollback "${APP_NAME}" "${previous_revision}" -n "${NAMESPACE}" --wait --timeout "${HELM_TIMEOUT}"; then
    if kubectl rollout status "deployment/${APP_NAME}" -n "${NAMESPACE}" --timeout="${HELM_TIMEOUT}"; then
      echo "Rollback rollout completed. Verifying restored service..."
      if smoke_test; then
        echo "RECOVERY SUCCEEDED: previous release is healthy."
      else
        echo "RECOVERY WARNING: rollback completed but smoke test failed."
      fi
    else
      echo "RECOVERY WARNING: rollout did not become healthy after rollback."
    fi
  else
    echo "RECOVERY FAILED: Helm rollback command failed."
  fi
else
  echo "No previous deployed revision exists; uninstalling failed first release."
  helm uninstall "${APP_NAME}" -n "${NAMESPACE}" --wait || true
fi
echo "Deployment failed; recovery procedure finished. Marking this build failed for visibility."
exit 1
