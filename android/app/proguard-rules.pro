# Release shrinking rules.
#
# R8 removes code it cannot see referenced. Several dependencies here are
# reached only reflectively or from native/platform code, so they must be kept
# explicitly or the release build fails at runtime with a
# ClassNotFoundException that never reproduces in debug.

# --- Flutter embedding -------------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# --- Firebase Cloud Messaging ------------------------------------------------
# The FCM service is instantiated by the OS from the manifest, not from Dart.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# --- flutter_local_notifications --------------------------------------------
# Scheduled notifications are rebuilt from a serialised payload after a
# device reboot, which is reflective.
-keep class com.dexterous.** { *; }
-keep class * extends android.app.NotificationChannel { *; }
-dontwarn com.dexterous.**

# --- Desugared java.time ----------------------------------------------------
-dontwarn java.time.**
-dontwarn j$.time.**

# --- Kotlin coroutines / serialization ---------------------------------------
-keepclassmembers class kotlinx.** { volatile <fields>; }
-dontwarn kotlinx.**
-dontwarn kotlin.**

# --- OkHttp / Conscrypt (Supabase realtime transport) ------------------------
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# --- Keep annotations used at runtime ---------------------------------------
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Preserve line numbers so a production stack trace stays readable, while
# still obfuscating names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
