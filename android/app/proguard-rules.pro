# Flutter WebRTC Proguard Rules
-keep class org.webrtc.** { *; }
-dontwarn org.webrtc.**

# Flutter CallKit Incoming Proguard Rules
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-dontwarn com.hiennv.flutter_callkit_incoming.**

# Firebase Messaging Proguard Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
