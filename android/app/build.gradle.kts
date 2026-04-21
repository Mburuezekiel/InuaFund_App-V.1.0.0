plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace "com.inuafund.inuafund"
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.inuafund.inuafund"
        minSdkVersion 21        // covers ~99% of Android devices in Kenya
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}

flutter {
    source = "../.."
}
