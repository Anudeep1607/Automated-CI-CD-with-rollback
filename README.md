# Automated CI/CD with Rollback

A beginner-to-intermediate DevOps portfolio lab: Jenkins tests a Flask app, builds and scans a Docker image, deploys to local Kubernetes with Helm, verifies health, and rolls back if a release is unhealthy.

## Stack
- Jenkins Pipeline, Git
- Python / Flask / unittest
- Docker, Minikube / Kubernetes, Helm
- Trivy image scanning

## Features
- Versioned local Docker image per Jenkins build
- Unit tests before deployment
- Container scan (informational by default)
- Readiness and liveness probes
- Helm-based deployment and rollback
- Controlled unhealthy-release parameter for rollback testing
- Release history and pipeline logs for troubleshooting

## Start here
Follow [SETUP_MACOS.md](SETUP_MACOS.md) for installation, Jenkins setup, testing, troubleshooting, and cleanup.

## Repository layout
- `app/` Flask application
- `tests/` unit tests
- `helm/demo-app/` Helm chart
- `scripts/deploy_with_rollback.sh` deployment, smoke test, and rollback helper
- `Dockerfile` container build
- `Jenkinsfile` pipeline definition

## Rollback test
1. Run the Jenkins job with `SIMULATE_BAD_RELEASE` unchecked; health should return HTTP 200.
2. Run again with it checked; Helm should fail readiness, the helper should restore the previous deployed revision, and the build should be marked failed to show that the attempted release was rejected.
3. Inspect `helm history demo-app -n devops-demo` and check `/health` again.

The unhealthy flag is only a disposable-lab test mechanism, not a production pattern.

## Security notes
- No cloud account is required for this project.
- Never commit credentials, tokens, `.env`, or kubeconfig files.
- Jenkins has significant local permissions when it can control Docker and Kubernetes; keep this lab isolated from production.
- Trivy findings are informational by default; review findings and choose a policy before making scans blocking.
- Do not claim performance or time-saving metrics unless you measure them.
