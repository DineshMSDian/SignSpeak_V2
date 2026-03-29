import os
import json
import numpy as np
import math
import glob

# Paths
RAW_DATA_DIR = '../data/raw_json'
OUT_DATA_DIR = '../data/processed_npy'

# Constants
SEQUENCE_LENGTH = 30  # Frames per sequence for ISL LSTM

def extract_features(frame_data):
    """
    Replicates the Flutter exact normalization logic to produce the 225-dim Float32 vector.
    """
    features = np.zeros(225, dtype=np.float32)
    
    # 1. Pose (Upper body, 25 points, Nose-relative)
    if frame_data.get('pose') and len(frame_data['pose']) >= 25:
        pose = frame_data['pose']
        ref = pose[0]  # nose is landmark 0
        idx = 0
        for i in range(25):
            p = pose[i]
            features[idx] = p.get('x', 0.0) - ref.get('x', 0.0)
            features[idx+1] = p.get('y', 0.0) - ref.get('y', 0.0)
            features[idx+2] = p.get('z', 0.0) - ref.get('z', 0.0)
            features[idx+3] = p.get('v', 0.0)
            idx += 4
            
    # 2. Left Hand (Wrist-relative, scale normalized)
    idx = 100
    if frame_data.get('left_hand') and len(frame_data['left_hand']) >= 21:
        hand = frame_data['left_hand']
        wrist = hand[0]
        mcp = hand[9]
        scale = math.sqrt(
            (mcp.get('x', 0) - wrist.get('x', 0))**2 + 
            (mcp.get('y', 0) - wrist.get('y', 0))**2 + 
            (mcp.get('z', 0) - wrist.get('z', 0))**2
        )
        if scale <= 0: scale = 1.0
        for i in range(21):
            features[idx] = (hand[i].get('x', 0) - wrist.get('x', 0)) / scale
            features[idx+1] = (hand[i].get('y', 0) - wrist.get('y', 0)) / scale
            features[idx+2] = (hand[i].get('z', 0) - wrist.get('z', 0)) / scale
            idx += 3
            
    # 3. Right Hand (Wrist-relative, scale normalized)
    idx = 163
    if frame_data.get('right_hand') and len(frame_data['right_hand']) >= 21:
        hand = frame_data['right_hand']
        wrist = hand[0]
        mcp = hand[9]
        scale = math.sqrt(
            (mcp.get('x', 0) - wrist.get('x', 0))**2 + 
            (mcp.get('y', 0) - wrist.get('y', 0))**2 + 
            (mcp.get('z', 0) - wrist.get('z', 0))**2
        )
        if scale <= 0: scale = 1.0
        for i in range(21):
            features[idx] = (hand[i].get('x', 0) - wrist.get('x', 0)) / scale
            features[idx+1] = (hand[i].get('y', 0) - wrist.get('y', 0)) / scale
            features[idx+2] = (hand[i].get('z', 0) - wrist.get('z', 0)) / scale
            idx += 3
            
    return features

def main():
    os.makedirs(OUT_DATA_DIR, exist_ok=True)
    
    json_files = glob.glob(os.path.join(RAW_DATA_DIR, '*.json'))
    if not json_files:
        print("⚠️ No JSON files found in data/raw_json/. Export data from the Flutter app first.")
        return

    asl_X, asl_y = [], []
    isl_X, isl_y = [], []

    # Process all gathered JSON files
    for filepath in json_files:
        print(f"Loading {filepath}...")
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        for key, frames in data.items():
            # key format: "ASL_A" or "ISL_HELLO"
            parts = key.split('_', 1)
            if len(parts) != 2:
                continue
                
            mode = parts[0].upper()
            label = parts[1].upper()
            
            # Convert all raw frames in this recording to normalized 225-dim vectors
            frame_vectors = [extract_features(frame) for frame in frames]
            
            if mode == 'ASL':
                # ASL is static: every frame is an independent training sample
                for vec in frame_vectors:
                    asl_X.append(vec)
                    asl_y.append(label)
                    
            elif mode == 'ISL':
                # ISL is dynamic: construct 30-frame sliding windows
                # E.g. 100 frames -> 71 overlapping samples of 30 frames each
                if len(frame_vectors) >= SEQUENCE_LENGTH:
                    for i in range(len(frame_vectors) - SEQUENCE_LENGTH + 1):
                        window = frame_vectors[i : i + SEQUENCE_LENGTH]
                        isl_X.append(window)
                        isl_y.append(label)

    # Save ASL datasets
    if asl_X:
        asl_X_np = np.array(asl_X, dtype=np.float32)
        asl_y_np = np.array(asl_y)
        np.save(os.path.join(OUT_DATA_DIR, 'asl_X.npy'), asl_X_np)
        np.save(os.path.join(OUT_DATA_DIR, 'asl_y.npy'), asl_y_np)
        print(f"✅ ASL Data saved: {asl_X_np.shape} samples.")
    else:
        print("No ASL data found.")

    # Save ISL datasets
    if isl_X:
        isl_X_np = np.array(isl_X, dtype=np.float32)
        isl_y_np = np.array(isl_y)
        np.save(os.path.join(OUT_DATA_DIR, 'isl_X.npy'), isl_X_np)
        np.save(os.path.join(OUT_DATA_DIR, 'isl_y.npy'), isl_y_np)
        print(f"✅ ISL Data saved: {isl_X_np.shape} sequences of length {SEQUENCE_LENGTH}.")
    else:
        print("No ISL data found.")

if __name__ == '__main__':
    main()
