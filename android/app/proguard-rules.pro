# Most Firebase/Google Play Services and Flutter plugin AARs ship their own
# consumer-proguard-rules.pro, which R8 merges in automatically — this file is
# only for anything that still breaks after enabling isMinifyEnabled. Re-run a
# release build and exercise auth, Firestore, push, and geolocation after any
# dependency bump; R8 stripping issues surface as runtime crashes, not build
# failures.

-keepattributes Signature
-keepattributes *Annotation*

# Google Sign-In & Firebase Auth Keep Rules
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.internal.auth.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

