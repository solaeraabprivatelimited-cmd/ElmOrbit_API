#!/bin/bash
set -e

# Force Python 3.11
echo "Using Python version:"
python3.11 --version

# Upgrade pip and build tools
python3.11 -m pip install --upgrade pip setuptools wheel

# Install requirements
python3.11 -m pip install -r monitoring_requirements.txt

echo "✅ Build completed successfully"
