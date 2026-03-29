import os
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, BatchNormalization
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

# Paths
DATA_DIR = '../data/processed_npy'
MODELS_DIR = '../models'
X_PATH = os.path.join(DATA_DIR, 'isl_X.npy')
y_PATH = os.path.join(DATA_DIR, 'isl_y.npy')
OUTPUT_MODEL = os.path.join(MODELS_DIR, 'isl_model.h5')
OUTPUT_TFLITE = os.path.join(MODELS_DIR, 'isl_model.tflite')
LABEL_MAP = os.path.join(MODELS_DIR, 'isl_label_map.json')

def main():
    if not os.path.exists(X_PATH) or not os.path.exists(y_PATH):
        print(f"❌ Missing Numpy data. Ensure you have exported ISL JSON from Flutter and run preprocess.py first.")
        return

    print("Loading datasets...")
    X = np.load(X_PATH)
    y_raw = np.load(y_PATH)

    print(f"Loaded ISL Data: X={X.shape}, y={y_raw.shape}")
    
    # Validation constraint
    if len(X.shape) != 3 or X.shape[1] != 60 or X.shape[2] != 225:
        print("❌ CRITICAL ERROR: ISL training data must be shape (samples, 60, 225).")
        return

    # 1. Encode string labels to categorical integers
    encoder = LabelEncoder()
    y_encoded = encoder.fit_transform(y_raw)
    y = tf.keras.utils.to_categorical(y_encoded)
    
    num_classes = len(encoder.classes_)
    
    # Save label mapping for testing/flutter display validation
    os.makedirs(MODELS_DIR, exist_ok=True)
    label_mapping = {int(i): str(cls) for i, cls in enumerate(encoder.classes_)}
    with open(LABEL_MAP, 'w') as f:
        json.dump(label_mapping, f)
    print(f"Saved API label map: {LABEL_MAP} ({num_classes} classes detected)")

    # 2. Train/Test split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.15, random_state=42)

    # 3. Build Long Short-Term Memory (LSTM) for 60-frame temporal sequence inference (2s @ 30fps)
    model = Sequential([
        LSTM(64, return_sequences=True, activation='tanh', input_shape=(60, 225)),
        Dropout(0.2),
        LSTM(128, return_sequences=True, activation='tanh'),
        Dropout(0.2),
        LSTM(64, return_sequences=False, activation='tanh'),
        BatchNormalization(),
        Dense(64, activation='relu'),
        Dense(32, activation='relu'),
        Dense(num_classes, activation='softmax')
    ])

    model.compile(optimizer='Adam', loss='categorical_crossentropy', metrics=['accuracy'])
    model.summary()

    # 4. Train Model
    checkpoint = ModelCheckpoint(OUTPUT_MODEL, monitor='val_accuracy', save_best_only=True, mode='max')
    early_stop = EarlyStopping(monitor='val_loss', patience=20, restore_best_weights=True)

    print("Training ISL Sequence model on CPU/GPU...")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=150,
        batch_size=32,
        callbacks=[checkpoint, early_stop]
    )

    # 5. Export to Google's TFLite format (Optimized for Mobile Flutter use)
    print(f"\nConverting to optimized TFLite format...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Enable TF Select Ops (Required for converting complex LSTMs to TFLite cleanly)
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS, 
        tf.lite.OpsSet.SELECT_TF_OPS 
    ]
    tflite_model = converter.convert()

    with open(OUTPUT_TFLITE, 'wb') as f:
        f.write(tflite_model)
        
    print(f"✅ ISL Training Complete!")
    print(f"TFLite Model saved to: {OUTPUT_TFLITE}")
    print("Next step: Move 'isl_model.tflite' to your Flutter /assets/models folder.")

if __name__ == '__main__':
    main()
