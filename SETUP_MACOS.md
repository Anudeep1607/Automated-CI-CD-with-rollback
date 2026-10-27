# Project 1: Jenkins CI/CD + Helm rollback on macOS

This lab runs locally and does not create AWS resources. Use a disposable local Kubernetes cluster, never a production cluster.

## 0. Prerequisites

- macOS with administrator access and an internet connection
- GitHub account (or another Git remote)
- 8 GB RAM recommended for Docker Desktop + Jenkins + Minikube
- Never commit passwords, access keys, `.env` files, or kubeconfig files

## 1. Install Homebrew (if needed)

Check:

```bash
brew --version
```

If needed, install Homebrew by following the current official instructions at https://brew.sh/.

## 2. Install tools

```bash
brew update
brew install openjdk@21 jenkins-lts minikube kubectl helm trivy python git
brew install --cask docker
```

Open Docker Desktop and wait until its engine is running:

```bash
open -a Docker
docker version
```

Check tools:

```bash
java -version
jenkins-lts --version
minikube version
kubectl version --client
helm version
trivy --version
python3 --version
git --version
```

If Java is not found, follow Homebrew's instructions for linking/configuring OpenJDK. Homebrew is commonly under `/opt/homebrew` on Apple Silicon and `/usr/local` on Intel Macs.

## 3. Start Minikube

```bash
minikube start --driver=docker
kubectl config use-context minikube
kubectl get nodes
```

Expected: one node in `Ready` state.

If startup fails:

```bash
minikube status
minikube logs
docker info
```

## 4. Create a Git repository

Extract the ZIP, then enter the project directory:

```bash
cd /path/to/devops-cicd-rollback
chmod +x scripts/deploy_with_rollback.sh
helm lint helm/demo-app
```

Initialize Git:

```bash
git init
git add .
git commit -m "Initial CI/CD rollback lab"
git branch -M main
```

Create an empty GitHub repository named `devops-cicd-rollback`, then replace the example URL with your own:

```bash
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/devops-cicd-rollback.git
git push -u origin main
```

Do not put a token in the URL. For a private repository, configure a read-only repository credential in Jenkins.

## 5. Configure Jenkins

Start the Homebrew service:

```bash
brew services start jenkins-lts
brew services list
```

Open `http://localhost:8080`. If the service uses another port, check its output/logs.

Try reading the initial admin password:

```bash
cat ~/.jenkins/secrets/initialAdminPassword
```

If this path does not exist, inspect the Homebrew service logs and Jenkins home path configured by the formula. Complete the setup wizard, install suggested plugins including Pipeline and Git, and create an administrator account.

### Important macOS permissions note

For this lab, Jenkins must be able to access Docker Desktop and the Minikube kubeconfig. Verify Jenkins runs as the same macOS user that can run `docker version`, `minikube status`, `kubectl get nodes`, and `helm version`. Do not solve permission errors by granting broad filesystem permissions.

The Jenkinsfile appends both common Homebrew bin paths to PATH. If Jenkins reports `command not found`, inspect the service environment and correct the PATH for your machine.

## 6. Create the Jenkins Pipeline job

1. Choose **New Item** in Jenkins.
2. Name it `devops-cicd-rollback`.
3. Select **Pipeline** and create the job.
4. Under **Pipeline**, select **Pipeline script from SCM**.
5. Select **Git**.
6. Enter your GitHub repository URL.
7. Set Branch Specifier to `*/main`.
8. Set Script Path to `Jenkinsfile`.
9. Save.

For a private repository, select the read-only credential you configured in Jenkins.

## 7. First run: healthy deployment

Run **Build Now** with `SIMULATE_BAD_RELEASE` unchecked. The pipeline should check out code, run tests, build the image, scan it with Trivy, load it into Minikube, deploy with Helm, and verify health.

Check the cluster:

```bash
kubectl get pods -n devops-demo
helm history demo-app -n devops-demo
kubectl port-forward service/demo-app 8080:5000 -n devops-demo
```

In a second Terminal window:

```bash
curl -i http://127.0.0.1:8080/health
curl -i http://127.0.0.1:8080/
```

Stop port-forwarding with Ctrl+C.

## 8. Second run: test automatic rollback

Run the Jenkins job again and check `SIMULATE_BAD_RELEASE`.

Expected:
- The image builds and loads.
- Helm attempts to deploy an unhealthy version.
- Readiness fails and Helm times out.
- The helper rolls back to the prior deployed revision.
- The helper verifies the restored service.
- Jenkins marks the attempted build **FAILURE**, because the attempted release was bad even if recovery succeeded.

Inspect:

```bash
helm history demo-app -n devops-demo
kubectl rollout status deployment/demo-app -n devops-demo
kubectl get pods -n devops-demo
kubectl port-forward service/demo-app 8080:5000 -n devops-demo
```

In another Terminal:

```bash
curl -i http://127.0.0.1:8080/health
```

After a successful rollback, expect HTTP 200 and `{"status":"ok"}`.

If the first-ever release is run with the bad-release flag, there is no previous healthy revision, so the helper uninstalls the failed release.

## 9. Troubleshooting

### `docker: command not found` in Jenkins
The Jenkins service PATH may not include Homebrew's bin directory. Inspect the service environment and configure PATH.

### Jenkins cannot connect to Docker
Ensure Docker Desktop is running and Jenkins runs as a macOS user permitted to access it.

### Jenkins cannot connect to Minikube
Check `minikube status`, `kubectl config current-context`, and the Jenkins service user's kubeconfig. Never commit kubeconfig to Git.

### `ImagePullBackOff` or `ErrImagePull`
The chart uses `imagePullPolicy: Never`. Confirm the tag was loaded:

```bash
minikube image ls | grep demo-app
```

The image tag must match the Jenkins build number.

### Rollback test takes time
The unhealthy readiness probe makes Helm wait until its timeout (default 60 seconds). Wait for the pipeline to finish before starting another build.

### Port-forward fails
Check:

```bash
kubectl get deploy,pods,svc -n devops-demo
kubectl describe deployment demo-app -n devops-demo
kubectl logs deployment/demo-app -n devops-demo
```

## 10. Clean up

```bash
helm uninstall demo-app -n devops-demo
kubectl delete namespace devops-demo
minikube stop
```

To delete the local cluster completely:

```bash
minikube delete
```

Stop Jenkins if you no longer need it:

```bash
brew services stop jenkins-lts
```

Docker Desktop and local image cache may still consume disk. Remove only images you recognize and no longer need.

## What to document in GitHub

- Architecture diagram and tool versions
- Pipeline stages
- Screenshot of successful deployment
- Screenshot of failed deployment and successful rollback
- `helm history` output showing revisions
- Security decisions, limitations, and future improvements

Do not claim uptime, time saved, or deployment improvement metrics unless you measured them.
