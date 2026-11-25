import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningPropertiesFile = rootProject.file("key.properties")
val releaseSigningProperties = Properties().apply {
    if (releaseSigningPropertiesFile.exists()) {
        releaseSigningPropertiesFile.inputStream().use { load(it) }
    }
}
val releaseSigningRequiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val releaseSigningConfigured = releaseSigningRequiredKeys.all {
    !releaseSigningProperties.getProperty(it).isNullOrBlank()
} && rootProject.file(releaseSigningProperties.getProperty("storeFile", "")).isFile

android {
    namespace = "com.smebuddy.sme_buddy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.smebuddy.sme_buddy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningConfigured) {
                storeFile = rootProject.file(releaseSigningProperties.getProperty("storeFile"))
                storePassword = releaseSigningProperties.getProperty("storePassword")
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never sign a production release with the publicly known debug key.
            signingConfig = if (releaseSigningConfigured) {
                signingConfigs.getByName("release")
            } else {
                null
            }
        }
    }
}

// Fail rather than emit an unsigned or debug-signed release artifact.
tasks.configureEach {
    val createsReleaseArtifact = name.contains("Release") &&
        (name.startsWith("assemble") || name.startsWith("bundle") || name.startsWith("package") || name.startsWith("sign"))
    if (createsReleaseArtifact) {
        doFirst {
            check(releaseSigningConfigured) {
                "Android release signing is not configured. Create android/key.properties and provide a protected release keystore."
            }
        }
    }
}

flutter {
    source = "../.."
}
