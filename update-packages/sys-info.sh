#!/bin/bash

echo "=== CPU ==="
lscpu | grep -E 'Model name|CPU\(s\)|Thread|Core'

echo
echo "=== RAM ==="
free -h

echo
echo "=== GPU ==="
lspci | grep -Ei 'vga|3d|display' || echo "No GPU detected via lspci"

echo
echo "=== NVIDIA ==="
nvidia-smi 2>/dev/null || echo "No NVIDIA GPU / nvidia-smi unavailable"
