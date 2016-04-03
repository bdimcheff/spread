#!/bin/sh
set -e

NODE_IP="127.0.0.1"

function retry() {
    COMMAND=$1
    RETRIES=5

    # override default if retry count is set
    if [ -n "$2" ]; then
        RETRIES=$2
    fi

    for i in {1..$RETRIES}; do eval "$COMMAND" && return || sleep 1; done
    echo "Failed to: $1"
    exit 1
}

KUBECTL="./build/kubectl"
MATTERMOST="./build/mattermost"
export PATH="./build:$PATH"

if [ ! -f $KUBECTL ]; then
    echo "Installing kubectl..."
    curl -o $KUBECTL https://storage.googleapis.com/kubernetes-release/release/v1.2.1/bin/linux/amd64/kubectl
    chmod +x $KUBECTL
fi

echo "Starting up localkube server"
spread cluster start

if [ ! -d "$MATTERMOST" ]; then
    echo "Cloning mattermost deployment repo"
    git clone http://github.com/redspread/kube-mattermost $MATTERMOST
fi

echo "Deploying demo..."
retry "spread deploy $MATTERMOST"

echo "Checking if service had been created"
retry "kubectl get services/mattermost-app"

echo "Getting node port..."
NODE_PORT=$(kubectl get services/mattermost-app --template='{{range .spec.ports}}{{printf "%g" .nodePort}}{{end}}')

echo "Checking if started app successfully"
retry "curl --fail http://$NODE_IP:$NODE_PORT" 10
