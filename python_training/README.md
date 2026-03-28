# SignSpeak_V2 Python Training Pipeline

This directory contains the machine learning backend that takes the raw JSON landmark dumps from the Flutter app, processes them into Tensors, and trains the `.tflite` models for on-device inference.

## Directory Structure
- `data/raw_json/`: Drop your exported `.json` files from the Flutter app here.
- `data/processed_npy/`: Auto-generated Numpy arrays ready for model consumption.
- `models/`: Where the final `.h5` and `.tflite` files will be saved.
- `src/`: The training scripts.

## Setup
1. `cd python_training`
2. `python -m venv venv`
3. `venv\Scripts\activate` (Windows)
4. `pip install -r requirements.txt`
