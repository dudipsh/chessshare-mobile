# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Supabase/GoTrue
-keep class io.supabase.** { *; }
-keep class com.google.gson.** { *; }

# Keep Stockfish native library
-keep class stockfish.** { *; }

# Keep model classes (if using JSON serialization)
-keepattributes *Annotation*
-keepattributes Signature

# Prevent R8 from removing methods that are called via reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Keep vibration
-keep class com.benjamindean.** { *; }

# Google Play Core (deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
