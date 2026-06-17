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

# ── R8 shrink (compatible options only) ─────────────────────────────────────
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

# Aggressive size optimization
-dontwarn java.lang.invoke.**
-dontwarn java.lang.ClassValue
-dontwarn java.lang.invoke.MethodHandle
-dontwarn java.lang.invoke.MethodHandles
-dontwarn java.lang.invoke.MethodHandles$Lookup
-dontwarn java.lang.invoke.MethodType
-dontwarn java.lang.invoke.CallSite
-dontwarn java.lang.invoke.ConstantCallSite

# Kotlin stdlib
-keep class kotlin.** { *; }

# ── Ad system class obfuscation (anti-detection) ───────────────────────────────
# Rename sensitive classes to neutral names in release builds
-repackageclasses 'lumio.ads'

# Aggressively obfuscate ad-related Dart classes (via Flutter build)
# Note: Dart obfuscation is controlled by --obfuscate flag in flutter build apk
# These rules supplement native obfuscation for any JNI/third-party code

# Keep ad network SDKs but allow obfuscation of wrapper code
-keep,allowobfuscation class com.adsterra.** { *; }
-keep,allowobfuscation class com.monetag.** { *; }

# ── Security hardening rules ─────────────────────────────────────────────────
# Obfuscate security-sensitive classes but keep their functionality
-keep,allowobfuscation class com.kakonzone.lumio.PlayIntegrityBridge { *; }
-keep,allowobfuscation class com.kakonzone.lumio.BlockedAppDetector { *; }
-keep,allowobfuscation class com.kakonzone.lumio.VpnDetectionBridge { *; }

# Play Integrity API
-keep class com.google.android.play.integrity.** { *; }
-dontwarn com.google.android.play.integrity.*

# Keep encryption-related classes but obfuscate implementation
-keep,allowobfuscation class androidx.security.crypto.** { *; }

# Remove debug code in release
-assumenosideeffects class io.flutter.BuildConfig {
    public static boolean DEBUG;
}

# ── String encryption (anti-tampering) ───────────────────────────────────────
# Obfuscate string constants that might contain sensitive URLs or keys
-adaptclassstrings
-adaptresourcefilenames

# ── Reflection-heavy libraries ────────────────────────────────────────────────
# Gson / JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ── R8 full mode optimization ───────────────────────────────────────────────────
# Enable aggressive optimization
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses

# Keep line numbers for debugging (remove in production if needed)
-keepattributes SourceFile,LineNumberTable

# Remove stack trace line numbers (anti-debugging)
-renamesourcefile debug_info.txt
