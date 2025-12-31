# Project Customization Log: ComfyUI-Custom

**Source Base:** `comfyui-base` (original template)
**Goal:** Create a private, "Slim" ComfyUI image with automated model downloading, dynamic node installation, and SSH-based file management, removing FileBrowser and JupyterLab.

## 1. Dockerfile Modifications

**Target File:** `Dockerfile`

**Changes Made:**
1.  **Removed Web Tools**: Deleted all instructions related to installing and configuring `filebrowser` (port 8080) and `jupyterlab` (port 8888).
2.  **Added System Tools**: 
    *   `rsync`: For efficient file transfer via SSH.
    *   `socat`: For bridging Port 80 to 8188 (RunPod Proxy support).
    *   `iproute2`: For network debugging (`ip` command).
3.  **Refactored Custom Nodes**: Removed hardcoded `git clone` commands for specific custom nodes (ControlNet, AnimateDiff, etc.) in the `builder` stage. Kept only `ComfyUI-Manager` as a base.
4.  **Added Python Tooling**: Added `pip install comfy-cli`.
5.  **Expose Ports**: Updated `EXPOSE` to only list `8188` (ComfyUI) and `22` (SSH).

## 2. Startup Script Restructuring

**Target File:** `start.sh`

**Changes Made:**
1.  **Configuration Variables**: Added variables at the top for easy user customization:
    *   `CUSTOM_NODES`: Space-separated GitHub URLs to clone on boot.
    *   `CHECKPOINT_MODELS`, `VAE_MODELS`, etc.: URLs for automated downloading.
2.  **Model Download Function**: Implemented `download_models()` to handle file downloading with existence checks (skips if file exists).
3.  **Dynamic Node Installation**:
    *   Created a loop to process `CUSTOM_NODES`.
    *   **Logic**: Clone repo -> Activate Venv -> Install `requirements.txt` -> Run `install.py` -> Run `setup.py`.
4.  **Network Bridging**: Added a background `socat` process to forward traffic from Port 80 to localhost:8188, ensuring compatibility with RunPod's HTTP Proxy.
5.  **Environment Preservation**: Enhanced SSH setup to ensure `PermitUserEnvironment yes` is set and environment variables are exported to SSH sessions.
6.  **Cleanup**: Removed logic for creating FileBrowser databases and Jupyter configs.

## 3. New Files

**File:** `emergency_setup.sh`
**Purpose:** A portable "patch script" that mimics the node/model setup logic of `start.sh`.
**Use Case:** Can be run on *any* standard ComfyUI container to install your preferred nodes and models without rebuilding the Docker image.

## 4. Current Configuration State

**Custom Nodes Active:**
- `rgthree-comfy`
- `ComfyUI-KJNodes`
- `ComfyUI-RunpodDirect`

**Models:**
- `z-image-turbo-bf16-aio.safetensors`

## 5. Build & Deploy Instructions

**Build:**
```bash
docker build -t comfyui-custom .
```

**Push (Example for Docker Hub):**
```bash
docker tag comfyui-custom:latest <username>/comfyui-custom:latest
docker push <username>/comfyui-custom:latest
```

**Run (Local/Dev):**
```bash
docker run -d -p 8188:8188 --gpus all comfyui-custom
```
