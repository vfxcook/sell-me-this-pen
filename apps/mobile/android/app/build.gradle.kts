plugins {
    id("com.android.application")
    // The Flutter Gradle plugin must be applied after the Android and
    // Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sellmethispen.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Specify your own unique application ID.
        applicationId = "com.sellmethispen.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing config is intentionally NOT committed here.
            // TODO: add a release signing config (keystore properties)
            // before producing a signed release APK/AAB in Phase 6.
            // Debug builds sign automatically with the debug key.
            // NOTE: do not set isMinifyEnabled here — the Flutter
            // plugin pairs it with resource shrinking, and setting
            // one without the other fails AGP 9 configuration.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // No additional Android dependencies yet. Network access uses
    // Flutter's Dio client; no native SDK is bundled.
}
