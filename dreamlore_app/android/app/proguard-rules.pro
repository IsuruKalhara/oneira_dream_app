# Flutter's embedding is reached reflectively from the platform side, so R8
# cannot see the references and would strip it.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core is referenced by Flutter's deferred-components support even when
# the app uses no deferred components; without this R8 warns and can strip it.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Firebase and Google Sign-In read annotations and construct model classes by
# reflection; obfuscating their names breaks token parsing at runtime.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Keep the line numbers, or a Crashlytics stack trace names a method and no
# line — which is most of the value gone.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
