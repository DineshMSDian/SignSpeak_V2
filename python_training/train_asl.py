# train_asl.py
# Train MLP model for ASL fingerspelling recognition
# Architecture: Dense(256) → BN → Dropout(0.3) → Dense(128) → BN → Dropout(0.2) → Dense(64) → Dense(26)
# Input: (batch, 225) single-frame features
# Output: (batch, 26) softmax over A-Z
#
# Usage: uv pip install tensorflow numpy scikit-learn
#        python train_asl.py

# TODO: Implement
