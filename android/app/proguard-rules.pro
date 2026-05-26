# LUMIO ProGuard / R8 — রিলিজ অবফাসকেশন
# বাংলা: Flutter + প্লাগইন রাখুন, লগ সরান, অ্যাপ কোড অবফাসকেট করুন

# ── Flutter engine (অবশ্যই রাখতে হবে) ─────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Unity / IronSource / Ad networks
-keep class com.unity3d.** { *; }
-keep class com.ironsource.** { *; }
-dontwarn com.unity3d.**
-dontwarn com.ironsource.**

# audio_service
-keep class com.ryanheise.audioservice.** { *; }

# media_kit (libmpv JNI)
-keep class com.alexmercerind.media_kit.** { *; }
-keep class com.alexmercerind.media_kit_video.** { *; }
-keep class is.xyz.mpv.** { *; }
-dontwarn com.alexmercerind.media_kit.**
-dontwarn is.xyz.mpv.**

# JNI নিরাপত্তা নেটিভ
-keepclasseswithmembernames class * {
    native <methods>;
}
-keep class com.kakonzone.lumio.MainActivity { *; }

# ── অবফাসকেশন অপ্টিমাইজেশন ────────────────────────────────────────────────
-optimizationpasses 5
-allowaccessmodification
-repackageclasses 'lumio.obf'
-flattenpackagehierarchy 'lumio.obf'

# ── লগিং সরান (রিলিজ) ───────────────────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Kotlin metadata
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Parcelable / Serializable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# WebView (Adsterra)
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(android.webkit.WebView, java.lang.String, android.graphics.Bitmap);
    public boolean *(android.webkit.WebView, java.lang.String);
}
-keepclassmembers class * extends android.webkit.WebChromeClient {
    public void *(android.webkit.WebView, java.lang.String);
}

-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
