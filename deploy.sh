#!/bin/bash
set -Eeuo pipefail

# ---------- Config ----------
APP_NAME="react-app"
IMAGE_NAME="jebin2703/react-app"
NAMESPACE="default"
MANIFEST="k8s-deployment.yaml"
BRANCH="main"
ROLLOUT_TIMEOUT="120s"

# Always run from the project directory (where this script lives)
cd "$(dirname "$0")"

echo "======================================"
echo "   React Application Deployment"
echo "======================================"

# ---------- Pre-flight checks ----------
for cmd in git npm docker kubectl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' is not installed"; exit 1; }
done
[ -f "$MANIFEST" ] || { echo "ERROR: $MANIFEST not found in $(pwd)"; exit 1; }
[ -f backup-cronjob.yaml ] || { echo "ERROR: backup-cronjob.yaml not found"; exit 1; }
grep -q "image: $IMAGE_NAME" "$MANIFEST" || { echo "ERROR: '$MANIFEST' has no 'image: $IMAGE_NAME...' line"; exit 1; }

echo ""
echo "1. Project directory: $(pwd)"

echo ""
echo "2. Pulling latest code..."
git pull --ff-only origin "$BRANCH"

# Unique tag per commit, so Kubernetes always sees a new image and rolls out
IMAGE_TAG="$(git rev-parse --short HEAD)"
echo "   Image tag: $IMAGE_TAG"

echo ""
echo "3. Installing dependencies..."
npm ci

echo ""
echo "4. Building React application..."
npm run build

echo ""
echo "5. Building Docker image..."
docker build -t "$IMAGE_NAME:$IMAGE_TAG" -t "$IMAGE_NAME:latest" .

echo ""
echo "6. Pushing Docker image to Docker Hub..."
docker push "$IMAGE_NAME:$IMAGE_TAG"
docker push "$IMAGE_NAME:latest"

echo ""
echo "7. Applying Kubernetes deployment with image $IMAGE_NAME:$IMAGE_TAG ..."
sed -E "s|image: ${IMAGE_NAME}(:[^[:space:]]*)?|image: ${IMAGE_NAME}:${IMAGE_TAG}|" "$MANIFEST" \
  | kubectl apply -n "$NAMESPACE" -f -

echo ""
echo "8. Waiting for rollout..."
if ! kubectl rollout status deployment/"$APP_NAME" -n "$NAMESPACE" --timeout="$ROLLOUT_TIMEOUT"; then
  echo "ERROR: rollout failed, rolling back..."
  kubectl rollout undo deployment/"$APP_NAME" -n "$NAMESPACE"
  exit 1
fi

echo ""
echo "9. Pods:"
kubectl get pods -n "$NAMESPACE" -l app="$APP_NAME" 2>/dev/null || kubectl get pods -n "$NAMESPACE"

echo ""
echo "10. Services:"
kubectl get services -n "$NAMESPACE"

echo ""
echo "======================================"
echo "   Deployment Completed Successfully"
echo "======================================"
