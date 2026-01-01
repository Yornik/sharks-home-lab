#!/usr/bin/env bash
set -euo pipefail

# Minimal GitOps scaffold for Argo CD app-of-apps
# Usage:
#   ./bootstrap.sh <repo_url> [cluster_name]
# Example:
#   ./bootstrap.sh https://github.com/YOURUSER/homelab-gitops.git yornik-homo-home-lab

REPO_URL="${1:-}"
CLUSTER_NAME="${2:-yornik-homo-home-lab}"

if [ -z "$REPO_URL" ]; then
  echo "ERROR: repo_url required"
  echo "Usage: $0 <repo_url> [cluster_name]"
  exit 1
fi

BASE="."
BOOTSTRAP="${BASE}/bootstrap"
APPS="${BASE}/apps"

mkdir -p "$BOOTSTRAP"
mkdir -p "${APPS}/infra"
mkdir -p "${APPS}/tools"
mkdir -p "${APPS}/media"
mkdir -p "${APPS}/monitoring"

# Root "app of apps"
cat > "${BOOTSTRAP}/root-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: ${APPS}
    directory:
      recurse: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Optional but useful: namespace manifests (so you control labels, PSA, etc.)
mkdir -p "${APPS}/infra/namespaces/manifests"

cat > "${APPS}/infra/namespaces/manifests/namespaces.yaml" <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: infra
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/audit: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: tools
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/audit: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: media
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/audit: baseline
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/warn: baseline
    pod-security.kubernetes.io/audit: baseline
EOF

# Child app for namespaces (so Argo applies them)
cat > "${APPS}/infra/namespaces/application.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: namespaces
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: ${APPS}/infra/namespaces/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: kube-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo "Created:"
echo "  ${BOOTSTRAP}/root-app.yaml"
echo "  ${APPS}/infra/namespaces/application.yaml"
echo "  ${APPS}/infra/namespaces/manifests/namespaces.yaml"
echo
echo "Next steps:"
echo "  git add . && git commit -m 'Bootstrap app-of-apps' && git push"
echo "  kubectl apply -f ${BOOTSTRAP}/root-app.yaml"

