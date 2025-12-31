# ComfyUI Custom

A slim, automated ComfyUI environment designed for easy customization and portable deployment. This is a private customization based on the `comfyui-base` template.

## Quick Start

### 1. Build the image
```bash
docker build -t comfyui-custom .
```

### 2. Run the container
```bash
docker run -d -p 8188:8188 --gpus all comfyui-custom
```

- **Web UI**: Access at `http://localhost:8188`
- **SSH**: Access at `port 22`

## Customization (Editing `start.sh`)

Most customizations can be done without rebuilding the image by editing the variables at the top of `start.sh`:

### 1. Manage Custom Nodes
Add GitHub URLs to the `CUSTOM_NODES` variable. The script will automatically clone the nodes and install requirements on startup.
```bash
CUSTOM_NODES="https://github.com/rgthree/rgthree-comfy.git https://github.com/kijai/ComfyUI-KJNodes"
```

### 2. Automated Model Downloads
Paste direct download URLs for your models. Filenames are automatically extracted from the URLs.
- `CHECKPOINT_MODELS`: Saved to `/models/checkpoints/`
- `TEXT_ENCODER_MODELS`: Saved to `/models/text_encoders/`
- `DIFFUSION_MODELS`: Saved to `/models/diffusion_models/`
- `VAE_MODELS`: Saved to `/models/vae/`

## File Transfer & Access

This image is slimmed down (FileBrowser and JupyterLab removed). Use **SSH** and **Rsync** for file management.

### Sync outputs to local computer:
```bash
rsync -avz -e ssh root@<IP_ADDRESS>:/workspace/runpod-slim/ComfyUI/output ./comfy_outputs
```

## Features
- **Comfy-CLI**: Pre-installed for command-line management.
- **Dynamic Startup**: Handles `requirements.txt`, `install.py`, and `setup.py` for all custom nodes.
- **Slim Image**: Focused only on ComfyUI and essential remote access tools.
- **SSH Service**: Running on port 22 for secure terminal and file access.

---
*Created and maintained by Herwin (Private).*
