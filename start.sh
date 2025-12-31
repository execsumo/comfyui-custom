#!/bin/bash
set -e  # Exit the script if any statement returns a non-true return value

COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
VENV_DIR="$COMFYUI_DIR/.venv"

# ---------------------------------------------------------------------------- #
#                             Customizable Models                               #
# ---------------------------------------------------------------------------- #
# Add URLs for models here (space-separated)
CHECKPOINT_MODELS="https://huggingface.co/SeeSee21/Z-Image-Turbo-AIO/resolve/main/z-image-turbo-bf16-aio.safetensors"
TEXT_ENCODER_MODELS=""
DIFFUSION_MODELS=""
VAE_MODELS=""

# Add URLs for ComfyUI custom nodes here (space-separated)
CUSTOM_NODES="https://github.com/rgthree/rgthree-comfy.git https://github.com/kijai/ComfyUI-KJNodes https://github.com/MadiatorLabs/ComfyUI-RunpodDirect"

# ---------------------------------------------------------------------------- #
#                          Function Definitions                                  #
# ---------------------------------------------------------------------------- #

# Reusable function for downloading models
download_models() {
    local urls="$1"
    local target_dir="$2"
    local type_name="$3"

    if [[ ! -z "$urls" ]]; then
        mkdir -p "$target_dir"
        for url in $urls; do
            filename=$(basename "$url")
            if [ ! -f "$target_dir/$filename" ]; then
                echo "Downloading $type_name: $filename..."
                wget -q --show-progress -O "$target_dir/$filename" "$url"
            else
                echo "$type_name $filename already exists, skipping."
            fi
        done
    fi
}

# Setup SSH with optional key or random password
setup_ssh() {
    mkdir -p ~/.ssh
    
    # Generate host keys if they don't exist
    for type in rsa dsa ecdsa ed25519; do
        if [ ! -f "/etc/ssh/ssh_host_${type}_key" ]; then
            ssh-keygen -t ${type} -f "/etc/ssh/ssh_host_${type}_key" -q -N ''
            echo "${type^^} key fingerprint:"
            ssh-keygen -lf "/etc/ssh/ssh_host_${type}_key.pub"
        fi
    done

    # If PUBLIC_KEY is provided, use it
    if [[ $PUBLIC_KEY ]]; then
        echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
        chmod 700 -R ~/.ssh
    else
        # Generate random password if no public key
        RANDOM_PASS=$(openssl rand -base64 12)
        echo "root:${RANDOM_PASS}" | chpasswd
        echo "Generated random SSH password for root: ${RANDOM_PASS}"
    fi

    # Configure SSH to preserve environment variables
    echo "PermitUserEnvironment yes" >> /etc/ssh/sshd_config

    # Start SSH service
    /usr/sbin/sshd
}

# Export environment variables
export_env_vars() {
    echo "Exporting environment variables..."
    
    # Create environment files
    ENV_FILE="/etc/environment"
    PAM_ENV_FILE="/etc/security/pam_env.conf"
    SSH_ENV_DIR="/root/.ssh/environment"
    
    # Backup original files
    cp "$ENV_FILE" "${ENV_FILE}.bak" 2>/dev/null || true
    cp "$PAM_ENV_FILE" "${PAM_ENV_FILE}.bak" 2>/dev/null || true
    
    # Clear files
    > "$ENV_FILE"
    > "$PAM_ENV_FILE"
    mkdir -p /root/.ssh
    > "$SSH_ENV_DIR"
    
    # Export to multiple locations for maximum compatibility
    printenv | grep -E '^RUNPOD_|^PATH=|^_=|^CUDA|^LD_LIBRARY_PATH|^PYTHONPATH' | while read -r line; do
        # Get variable name and value
        name=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2-)
        
        # Add to /etc/environment (system-wide)
        echo "$name=\"$value\"" >> "$ENV_FILE"
        
        # Add to PAM environment
        echo "$name DEFAULT=\"$value\"" >> "$PAM_ENV_FILE"
        
        # Add to SSH environment file
        echo "$name=\"$value\"" >> "$SSH_ENV_DIR"
        
        # Add to current shell
        echo "export $name=\"$value\"" >> /etc/rp_environment
    done
    
    # Add sourcing to shell startup files
    echo 'source /etc/rp_environment' >> ~/.bashrc
    echo 'source /etc/rp_environment' >> /etc/bash.bashrc
    
    # Set permissions
    chmod 644 "$ENV_FILE" "$PAM_ENV_FILE"
    chmod 600 "$SSH_ENV_DIR"
}


# ---------------------------------------------------------------------------- #
#                               Main Program                                     #
# ---------------------------------------------------------------------------- #

# Setup environment
setup_ssh
export_env_vars

# Create default comfyui_args.txt if it doesn't exist
ARGS_FILE="/workspace/runpod-slim/comfyui_args.txt"
if [ ! -f "$ARGS_FILE" ]; then
    mkdir -p "/workspace/runpod-slim"
    echo "# Add your custom ComfyUI arguments here (one per line)" > "$ARGS_FILE"
    echo "Created empty ComfyUI arguments file at $ARGS_FILE"
fi

# 1. Ensure ComfyUI is installed
if [ ! -d "$COMFYUI_DIR" ]; then
    echo "Cloning ComfyUI..."
    mkdir -p "/workspace/runpod-slim"
    cd /workspace/runpod-slim
    git clone https://github.com/comfyanonymous/ComfyUI.git
fi

# 2. Ensure Virtual Environment is setup
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    cd $COMFYUI_DIR
    python3.12 -m venv --system-site-packages $VENV_DIR
    source $VENV_DIR/bin/activate
    python -m ensurepip --upgrade
    python -m pip install --upgrade pip
else
    source $VENV_DIR/bin/activate
fi

# 3. Ensure ComfyUI-Manager is installed (required for most setups)
if [ ! -d "$COMFYUI_DIR/custom_nodes/ComfyUI-Manager" ]; then
    echo "Installing ComfyUI-Manager..."
    mkdir -p "$COMFYUI_DIR/custom_nodes"
    cd "$COMFYUI_DIR/custom_nodes"
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
    cd ComfyUI-Manager && pip install -r requirements.txt
fi

# 4. Sync dynamic custom nodes from variable
for repo in $CUSTOM_NODES; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$COMFYUI_DIR/custom_nodes/$repo_name" ]; then
        echo "Installing new custom node: $repo_name..."
        cd "$COMFYUI_DIR/custom_nodes"
        git clone "$repo"
        
        # Install dependencies for the new node immediately
        cd "$COMFYUI_DIR/custom_nodes/$repo_name"
        if [ -f "requirements.txt" ]; then
            echo "Installing requirements for $repo_name..."
            pip install --no-cache-dir -r requirements.txt
        fi
        if [ -f "install.py" ]; then
            echo "Running install.py for $repo_name..."
            python install.py
        fi
        if [ -f "setup.py" ]; then
            echo "Running setup.py for $repo_name..."
            pip install --no-cache-dir -e .
        fi
    fi
done

# 5. Download models
download_models "$CHECKPOINT_MODELS" "$COMFYUI_DIR/models/checkpoints" "checkpoint"
download_models "$TEXT_ENCODER_MODELS" "$COMFYUI_DIR/models/text_encoders" "text_encoder"
download_models "$DIFFUSION_MODELS" "$COMFYUI_DIR/models/diffusion_models" "diffusion_model"
download_models "$VAE_MODELS" "$COMFYUI_DIR/models/vae" "vae"

# 6. Start ComfyUI
cd $COMFYUI_DIR
FIXED_ARGS="--listen 0.0.0.0 --port 8188"
if [ -s "$ARGS_FILE" ]; then
    CUSTOM_ARGS=$(grep -v '^#' "$ARGS_FILE" | tr '\n' ' ')
    if [ ! -z "$CUSTOM_ARGS" ]; then
        echo "Starting ComfyUI with additional arguments: $CUSTOM_ARGS"
        nohup python main.py $FIXED_ARGS $CUSTOM_ARGS &> /workspace/runpod-slim/comfyui.log &
    else
        echo "Starting ComfyUI with default arguments"
        nohup python main.py $FIXED_ARGS &> /workspace/runpod-slim/comfyui.log &
    fi
else
    echo "Starting ComfyUI with default arguments"
    nohup python main.py $FIXED_ARGS &> /workspace/runpod-slim/comfyui.log &
fi

# Tail the log file
tail -f /workspace/runpod-slim/comfyui.log
