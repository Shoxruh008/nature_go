import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yandex MapKit kaliti gitda saqlanmaydi: avval YANDEX_MAPKIT_API_KEY muhit
// o'zgaruvchisi (CI), so'ng android/yandex.properties (lokal) tekshiriladi.
val yandexProperties = Properties()
val yandexPropertiesFile = rootProject.file("yandex.properties")
if (yandexPropertiesFile.exists()) {
    yandexProperties.load(FileInputStream(yandexPropertiesFile))
}
val yandexMapKitApiKey: String =
    System.getenv("YANDEX_MAPKIT_API_KEY")
        ?: yandexProperties.getProperty("YANDEX_MAPKIT_API_KEY")
        ?: ""
if (yandexMapKitApiKey.isEmpty()) {
    logger.warn("YANDEX_MAPKIT_API_KEY berilmagan: xarita ishlamaydi (android/yandex.properties ni to'ldiring).")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.naturego.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.naturego.app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["yandexMapKitApiKey"] = yandexMapKitApiKey
        buildConfigField("String", "YANDEX_MAPKIT_API_KEY", "\"$yandexMapKitApiKey\"")
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.yandex.android:maps.mobile:4.22.0-lite")
}
