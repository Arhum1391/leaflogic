# tflite_flutter pulls in references to org.tensorflow.lite.gpu.* which only
# exist in the optional TFLite GPU delegate AAR. We use CPU-only inference,
# so the class is genuinely absent at runtime - tell R8 not to error on the
# missing references.
-dontwarn org.tensorflow.lite.gpu.**
-keep class org.tensorflow.lite.** { *; }

# google_sign_in / Play Services - keep model classes that survive R8 by
# being read reflectively from JSON.
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
