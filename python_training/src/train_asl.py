import os
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout, BatchNormalization
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

# Paths
DATA_DIR = '../data/processed_npy'
MODELS_DIR = '../models'
X_PATH = os.path.join(DATA_DIR, 'asl_X.npy')
y_PATH = os.path.join(DATA_DIR, 'asl_y.npy')
OUTPUT_MODEL = os.path.join(MODELS_DIR, 'asl_model.h5')
OUTPUT_TFLITE = os.path.join(MODELS_DIR, 'asl_model.tflite')
LABEL_MAP = os.path.join(MODELS_DIR, 'asl_label_map.json')

def main():
    if not os.path.exists(X_PATH) or not os.path.exists(y_PATH):
        print(f"❌ Missing Numpy data. Ensure you have exported ASL JSON from Flutter and run preprocess.py first.")
        return

    print("Loading datasets...")
    X = np.load(X_PATH)
    y_raw = np.load(y_PATH)

    print(f"Loaded ASL Data: X={X.shape}, y={y_raw.shape}")
    
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

    # 3. Build Multi-Layer Perceptron (MLP) for single-frame 225-dim inference
    # Architecture: 225 -> 256 -> 128 -> 64 -> num_classes 
    model = Sequential([
        Dense(256, activation='relu', input_shape=(225,)),
        BatchNormalization(),
        Dropout(0.3),
        Dense(128, activation='relu'),
        BatchNormalization(),
        Dropout(0.3),
        Dense(64, activation='relu'),
        BatchNormalization(),
        Dense(num_classes, activation='softmax')
    ])

    model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
    model.summary()

    # 4. Train Model
    checkpoint = ModelCheckpoint(OUTPUT_MODEL, monitor='val_accuracy', save_best_only=True, mode='max')
    early_stop = EarlyStopping(monitor='val_loss', patience=15, restore_best_weights=True)

    print("Training ASL model on CPU/GPU...")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=100,
        batch_size=32,
        callbacks=[checkpoint, early_stop]
    )

    # 5. Export to Google's TFLite format (Optimized for Mobile Flutter use)
    print(f"\nConverting to optimized TFLite format...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Enable aggressive quantization for faster mobile inference speeds
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open(OUTPUT_TFLITE, 'wb') as f:
        f.write(tflite_model)
        
    print(f"✅ ASL Training Complete!")
    print(f"TFLite Model saved to: {OUTPUT_TFLITE}")
    print("Next step: Move 'asl_model.tflite' to your Flutter /assets/models folder.")

if __name__ == '__main__':
    main()
