 import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // START: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Google Maps SDK key ────────────────────────────────────────────────────
// Đọc từ android/key.properties (KHÔNG commit file này lên git).
// Nếu thiếu file → dùng placeholder để build vẫn chạy được.
val mapsApiKey: String = run {
    val propsFile = rootProject.file("key.properties")
    if (propsFile.exists()) {
        val props = Properties().apply { propsFile.inputStream().use { load(it) } }
        props.getProperty("MAPS_API_KEY") ?: "YOUR_GOOGLE_MAPS_API_KEY"
    } else {
        "YOUR_GOOGLE_MAPS_API_KEY"
    }
}


android {
    namespace = "com.example.thunghiem1"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.thunghiem1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps SDK key (đọc từ android/key.properties)
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

 kotlin {
     compilerOptions {
         jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
     }
 }
