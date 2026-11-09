# Keep the Flutter engine and every plugin entry point. Everything else is
# shrunk and renamed by R8 for release builds.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class com.nfcstudio.nfc_studio.** { *; }
-keep class * extends android.app.Activity { *; }
-keep class * extends android.app.Application { *; }
-dontwarn io.flutter.**
-dontwarn androidx.**

# Supabase / okhttp / kotlinx serialization are used through reflection in a
# few places; keep their serializers intact.
-keepattributes Signature, InnerClasses, EnclosingMethod, *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn org.jetbrains.annotations.**

# Strip verbose/debug logging from the release binary.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
