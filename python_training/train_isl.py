# train_isl.py
# Train LSTM model for ISL gesture recognition
# Architecture: LSTM(64, return_seq) → LSTM(128) → Dense(64) → Dropout(0.3) → Dense(10)
# Input: (batch, 30, 225) sequence of 30 frames
# Output: (batch, 10) softmax over 10 ISL gestures
#
# Usage: uv pip install tensorflow numpy scikit-learn
#        python train_isl.py

# TODO: Implement
