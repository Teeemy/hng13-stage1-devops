#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
# --- End Configuration ---

# --- Helper Functions ---
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR: $1"
    exit 1
}

trap 'error_exit "An unexpected error occurred."' ERR

# --- Main Script ---

# 1. Prompt for and validate user input
read -p "Enter Git Repository URL: " GIT_REPO_URL
while [[ -z "$GIT_REPO_URL" ]]; do
    read -p "Git Repository URL cannot be empty. Please enter again: " GIT_REPO_URL
done

read  -p "Enter Personal Access Token (PAT): " GIT_PAT
echo
while [[ -z "$GIT_PAT" ]]; do
    read  -p "Personal Access Token cannot be empty. Please enter again: " GIT_PAT
    echo
done

read -p "Enter Branch name (optional; defaults to main): " GIT_BRANCH
GIT_BRANCH=${GIT_BRANCH:-main}

read -p "Enter remote server username: " REMOTE_USER
while [[ -z "$REMOTE_USER" ]]; do
    read -p "Remote server username cannot be empty. Please enter again: " REMOTE_USER
done

read -p "Enter remote server IP address: " REMOTE_IP
while [[ -z "$REMOTE_IP" ]]; do
    read -p "Remote server IP address cannot be empty. Please enter again: " REMOTE_IP
done

read -p "Enter path to your SSH private key: " SSH_KEY_PATH
# Expand ~ to full home directory path
SSH_KEY_PATH="${SSH_KEY_PATH/#\~/$HOME}"

if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH key not found at the specified path: $SSH_KEY_PATH"
    exit 1
fi

read -p "Enter the internal container port: " APP_PORT
while ! [[ "$APP_PORT" =~ ^[0-9]+$ ]] || [ "$APP_PORT" -lt 1 ] || [ "$APP_PORT" -gt 65535 ]; do
    read -p "Please enter a valid port number (1-65535): " APP_PORT
done

# --- Local Operations ---

# 2. Clone the Repository
REPO_NAME=$(basename "$GIT_REPO_URL" .git)
if [ -d "$REPO_NAME" ]; then
    log "Repository already exists. Pulling latest changes..."
    cd "$REPO_NAME"
    git pull
else
    log "Cloning the repository..."
    git clone "https://oauth2:${GIT_PAT}@${GIT_REPO_URL#https://}"
    cd "$REPO_NAME"
fi
git checkout "$GIT_BRANCH"

# 3. Navigate into the Cloned Directory and Verify Dockerfile
# Check if a Dockerfile exists anywhere in the repo
if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ] || [ -f ".devcontainer/Dockerfile" ]; then
    echo "✅ Docker configuration found."
else
    echo "❌ ERROR: No Dockerfile or docker-compose.yml found (even in .devcontainer/)."
    exit 1
fi


# --- Remote Operations ---

# 4. SSH into the Remote Server and Perform Connectivity Checks
log "Testing SSH connection to the remote server..."
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "${REMOTE_USER}@${REMOTE_IP}" "echo 'SSH connection successful.'"

# 5. Prepare the Remote Environment
log "Preparing the remote environment..."
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_IP}" << EOF
    set -e
    log() {
        echo "\$(date +'%Y-%m-%d %H:%M:%S') - \$1"
    }

    log "Updating system packages..."
    sudo apt-get update -y

    log "Installing dependencies..."
    sudo apt-get install -y ca-certificates curl gnupg lsb-release

    if ! command -v docker &> /dev/null; then
        log "Installing Docker..."
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo \
          "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          \$(. /etc/os-release && echo "\$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo usermod -aG docker ${REMOTE_USER}
    else
        log "Docker is already installed."
    fi

    if ! command -v nginx &> /dev/null; then
        log "Installing Nginx..."
        sudo apt-get install -y nginx
    else
        log "Nginx is already installed."
    fi

    log "Starting and enabling services..."
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo systemctl start nginx
    sudo systemctl enable nginx

    log "Confirming installation versions..."
    docker --version
    nginx -v
EOF

# 6. Deploy the Dockerized Application
log "Transferring project files to the remote server..."
rsync -avz -e "ssh -i ${SSH_KEY_PATH}" --exclude='.git' . "${REMOTE_USER}@${REMOTE_IP}:/tmp/${REPO_NAME}"

log "Deploying the application on the remote server..."
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_IP}" << EOF
    set -e
    log() {
        echo "\$(date +'%Y-%m-%d %H:%M:%S') - \$1"
    }
    cd "/tmp/${REPO_NAME}"

    if [ -f "docker-compose.yml" ]; then
        log "Stopping and removing existing containers defined in docker-compose.yml..."
        docker-compose down || true
        log "Building and running containers with docker-compose..."
        docker-compose up -d --build
    else
        log "Stopping and removing existing container..."
        docker stop ${REPO_NAME} || true
        docker rm ${REPO_NAME} || true
        log "Building and running container with Dockerfile..."
        docker build -f .devcontainer/Dockerfile -t ${REPO_NAME} .
        docker run -d --name ${REPO_NAME} -p ${APP_PORT}:${APP_PORT} ${REPO_NAME}

    fi
EOF

# 7. Configure Nginx as a Reverse Proxy
log "Configuring Nginx as a reverse proxy..."
NGINX_CONF="
server {
    listen 80;
    server_name ${REMOTE_IP};

    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
"
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_IP}" "echo '${NGINX_CONF}' | sudo tee /etc/nginx/sites-available/default > /dev/null"
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_IP}" "sudo nginx -t && sudo systemctl reload nginx"

# 8. Validate Deployment
log "Validating the deployment..."
ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_IP}" "docker ps"
log "Testing the application endpoint..."
curl -I "http://${REMOTE_IP}"

log "Deployment completed successfully!"

# 10. Optional Cleanup
if [[ "$1" == "--cleanup" ]]; then
    log "Cleaning up deployed resources..."
    ssh -i "$SSH_KEY_PATH" "${REMOTE_USER}@${REMOTE_IP}" << EOF
        set -e
        log() {
            echo "\$(date +'%Y-%m-%d %H:%M:%S') - \$1"
        }
        cd "/tmp/${REPO_NAME}"

        if [ -f "docker-compose.yml" ]; then
            docker-compose down
        else
            docker stop ${REPO_NAME} || true
            docker rm ${REPO_NAME} || true
        fi
        sudo rm /etc/nginx/sites-available/default
        sudo nginx -t && sudo systemctl reload nginx
        rm -rf "/tmp/${REPO_NAME}"
EOF
    log "Cleanup complete."
fi