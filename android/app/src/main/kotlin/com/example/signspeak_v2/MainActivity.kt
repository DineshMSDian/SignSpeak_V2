package com.example.signspeak_v2

import android.graphics.Bitmap
import android.util.Log
import androidx.annotation.NonNull
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.signspeak_v2/mediapipe"
    private var handLandmarker: HandLandmarker? = null
    private var poseLandmarker: PoseLandmarker? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    val success = initMediaPipe()
                    result.success(success)
                }
                "processImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    
                    if (bytes != null && width > 0 && height > 0) {
                        Thread {
                            val jsonStr = processFrame(bytes, width, height)
                            runOnUiThread {
                                result.success(jsonStr)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "Bytes, width, or height are missing.", null)
                    }
                }
                "dispose" -> {
                    handLandmarker?.close()
                    handLandmarker = null
                    poseLandmarker?.close()
                    poseLandmarker = null
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun initMediaPipe(): Boolean {
        try {
            val flutterLoader = io.flutter.FlutterInjector.instance().flutterLoader()
            val handModelPath = flutterLoader.getLookupKeyForAsset("assets/models/hand_landmarker.task")
            val poseModelPath = flutterLoader.getLookupKeyForAsset("assets/models/pose_landmarker_lite.task")

            val handBaseOptions = BaseOptions.builder().setModelAssetPath(handModelPath).build()
            val handOptions = HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(handBaseOptions)
                .setNumHands(1)
                .setRunningMode(RunningMode.IMAGE)
                .build()
            handLandmarker = HandLandmarker.createFromOptions(context, handOptions)

            val poseBaseOptions = BaseOptions.builder().setModelAssetPath(poseModelPath).build()
            val poseOptions = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(poseBaseOptions)
                .setRunningMode(RunningMode.IMAGE)
                .build()
            poseLandmarker = PoseLandmarker.createFromOptions(context, poseOptions)

            return true
        } catch (e: Exception) {
            Log.e("MediaPipe", "Initialization failed", e)
            return false
        }
    }

    private fun processFrame(rgbBytes: ByteArray, width: Int, height: Int): String {
        try {
            // Convert flat RGB byte array from Dart into ARGB_8888 Bitmap
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val pixels = IntArray(width * height)
            var idx = 0
            for (i in 0 until (width * height)) {
                val r = rgbBytes[idx].toInt() and 0xFF
                val g = rgbBytes[idx + 1].toInt() and 0xFF
                val b = rgbBytes[idx + 2].toInt() and 0xFF
                pixels[i] = (255 shl 24) or (r shl 16) or (g shl 8) or b
                idx += 3
            }
            bitmap.setPixels(pixels, 0, width, 0, 0, width, height)

            val mpImage = BitmapImageBuilder(bitmap).build()

            // Run tasks synchronously on background thread
            var handResult: HandLandmarkerResult? = null
            var poseResult: PoseLandmarkerResult? = null

            try { handResult = handLandmarker?.detect(mpImage) } catch (e:Exception) {}
            try { poseResult = poseLandmarker?.detect(mpImage) } catch (e:Exception) {}

            val jsonOutput = JSONObject()

            // Parse Hand
            if (handResult != null && handResult.landmarks().isNotEmpty()) {
                val handJson = JSONArray()
                val handIndex = 0 // Num hands = 1
                val landmarks = handResult.landmarks()[handIndex]
                val handednessCategory = handResult.handednesses()[handIndex].first()
                val score = handednessCategory.score()
                
                // Route to "leftHand" or "rightHand" dynamically
                // Bug #3 Fix!
                val isRight = handednessCategory.categoryName() == "Right"
                val handKey = if (isRight) "rightHand" else "leftHand"
                
                jsonOutput.put(handKey + "Confidence", score.toDouble())

                for (lm in landmarks) {
                    val lmJson = JSONObject()
                    lmJson.put("x", lm.x().toDouble())
                    lmJson.put("y", lm.y().toDouble())
                    lmJson.put("z", lm.z().toDouble())
                    handJson.put(lmJson)
                }
                jsonOutput.put(handKey, handJson)
            }

            // Parse Pose (limit to upper body = first 25 points)
            if (poseResult != null && poseResult.landmarks().isNotEmpty()) {
                val poseJson = JSONArray()
                val landmarks = poseResult.landmarks()[0]
                var avgScore = 0.0
                val limit = if (landmarks.size > 25) 25 else landmarks.size

                for (i in 0 until limit) {
                    val lm = landmarks[i]
                    val lmJson = JSONObject()
                    lmJson.put("x", lm.x().toDouble())
                    lmJson.put("y", lm.y().toDouble())
                    lmJson.put("z", lm.z().toDouble())
                    lmJson.put("v", lm.presence().orElse(0f).toDouble())
                    avgScore += lm.presence().orElse(0f).toDouble()
                    poseJson.put(lmJson)
                }
                avgScore /= limit
                
                jsonOutput.put("pose", poseJson)
                jsonOutput.put("poseConfidence", avgScore)
            }

            return jsonOutput.toString()
        } catch (e: Exception) {
            Log.e("MediaPipe", "Frame processing failed", e)
            return "{}"
        }
    }
}
