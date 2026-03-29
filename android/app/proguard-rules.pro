-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# MediaPipe tasks-vision SDK
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
