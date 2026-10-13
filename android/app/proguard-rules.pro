# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# TextInput и клавиатура
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.plugin.text.** { *; }
-keep class android.view.inputmethod.** { *; }
-keep class android.widget.EditText { *; }
-keep class android.widget.TextView { *; }

# ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.vision.text.**

# Google Play Core
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Gson
-keep class com.google.gson.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Keep native methods
-keepclasseswithmembernames class * { native <methods>; }

# Keep Parcelable
-keep class * implements android.os.Parcelable { public static final ** CREATOR; }