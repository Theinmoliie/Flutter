# Rules for Google ML Kit libraries
-keep public class com.google.mlkit.** {
    public *;
}
-dontwarn com.google.mlkit.**

# Rules for TensorFlow Lite, which is a dependency of ML Kit
-keep class org.tensorflow.lite.** {
    *;
}
-dontwarn org.tensorflow.lite.**