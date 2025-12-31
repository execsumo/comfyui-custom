#!/bin/bash
# ============================================================================
# ComfyUI-Custom: Emergency Setup Script
# ============================================================================
# Usage: 
# 1. SSH into any standard ComfyUI container (or RunPod base image)
# 2. Run: bash emergency_setup.sh
# 
# What it does:
# - Installs Cloudflare Tunnel (cloudflared) for emergency public access
# - Installs 'comfy-cli' for management
# - Downloads your custom models defined below
# - Installs your custom nodes defined below
# ============================================================================

set -e

# Configuration (Same as your start.sh)
COMFYUI_DIR="/workspace/runpod-slim/ComfyUI"
VENV_DIR="$COMFYUI_DIR/.venv"

# Custom Nodes to Install (space separated)
CUSTOM_NODES="https://github.com/rgthree/rgthree-comfy.git"

# Models to Download
CHECKPOINT_MODELS="https://huggingface.co/SeeSee21/Z-Image-Turbo-AIO/resolve/main/z-image-turbo-bf16-aio.safetensors"
TEXT_ENCODER_MODELS=""
DIFFUSION_MODELS=""
VAE_MODELS=""

# ---------------------------------------------------------------------------- #
#                               Functions                                        #
# ---------------------------------------------------------------------------- #

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


# ---------------------------------------------------------------------------- #
#                               Main Execution                                   #
# ---------------------------------------------------------------------------- #

echo ">>> Starting Emergency Setup..."

# 1. Install Comfy-CLI
if ! pip show comfy-cli &> /dev/null; then
    echo "Installing comfy-cli..."
    pip install comfy-cli
else
    echo "comfy-cli is already installed."
fi

# 2. Sync Custom Nodes
echo ">>> Syncing Custom Nodes..."
# Ensure ComfyUI exists (if using a different base image path, this might need adjustment)
if [ ! -d "$COMFYUI_DIR" ]; then
    # Fallback search for ComfyUI
    if [ -d "/workspace/ComfyUI" ]; then
        COMFYUI_DIR="/workspace/ComfyUI"
        echo "Found ComfyUI at $COMFYUI_DIR"
    elif [ -d "/ComfyUI" ]; then
         COMFYUI_DIR="/ComfyUI"
         echo "Found ComfyUI at $COMFYUI_DIR"
    else
        echo "ERROR: Could not find ComfyUI directory. Please edit the script with the correct path."
        exit 1
    fi
fi

# Activate venv if it exists
if [ -d "$COMFYUI_DIR/.venv" ]; then
    source "$COMFYUI_DIR/.venv/bin/activate"
fi

for repo in $CUSTOM_NODES; do
    repo_name=$(basename "$repo" .git)
    if [ ! -d "$COMFYUI_DIR/custom_nodes/$repo_name" ]; then
        echo "Installing $repo_name..."
        cd "$COMFYUI_DIR/custom_nodes"
        git clone "$repo"
        
        # Install dependencies
        cd "$COMFYUI_DIR/custom_nodes/$repo_name"
        if [ -f "requirements.txt" ]; then
            pip install --no-cache-dir -r requirements.txt
        fi
        if [ -f "install.py" ]; then
            python install.py
        fi
        if [ -f "setup.py" ]; then
           pip install --no-cache-dir -e .
        fi
    else
        echo "$repo_name already installed."
    fi
done

# 3. Download Models
echo ">>> Downloading Models..."
download_models "$CHECKPOINT_MODELS" "$COMFYUI_DIR/models/checkpoints" "checkpoint"
download_models "$TEXT_ENCODER_MODELS" "$COMFYUI_DIR/models/text_encoders" "text_encoder"
download_models "$DIFFUSION_MODELS" "$COMFYUI_DIR/models/diffusion_models" "diffusion_model"
download_models "$VAE_MODELS" "$COMFYUI_DIR/models/vae" "vae"

# 4. Final Output
echo "------------------------------------------------------------------"
echo "Setup Complete! Dependencies and models have been synced."
echo "You may need to restart ComfyUI for the new nodes to appear."
echo "------------------------------------------------------------------"
