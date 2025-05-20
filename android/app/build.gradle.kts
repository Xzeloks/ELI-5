import java.io.File // Keep for file handling

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Function to manually parse key.properties
fun getKeyStoreProperties(filePath: String): Map<String, String> {
    val properties = mutableMapOf<String, String>()
    val propertiesFile = project.file(filePath)
    if (propertiesFile.exists()) {
        propertiesFile.forEachLine { line ->
            val parts = line.split("=", limit = 2)
            if (parts.size == 2) {
                properties[parts[0].trim()] = parts[1].trim()
            }
        }
    } else {
        // println("Warning: Properties file not found at $filePath (resolved to ${propertiesFile.absolutePath}). Release builds may not be signed correctly.") // Keep this useful warning, but comment out for now as it's working.
    }
    return properties
}

val keyStoreProps = getKeyStoreProperties("key.properties")

android {
    namespace = "com.ahenyagan.eli5"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keyStoreProps["keyAlias"]
            keyPassword = keyStoreProps["keyPassword"]
            storeFile = if (keyStoreProps["storeFile"] != null && keyStoreProps["storeFile"]!!.isNotEmpty()) project.file(keyStoreProps["storeFile"]!!) else null
            storePassword = keyStoreProps["storePassword"]
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ahenyagan.eli5"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            // signingConfig = signingConfigs.getByName("debug") // KEEP THIS COMMENTED OR REMOVE
            // You might want to add ProGuard rules here if not already handled.
            // proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.13.0"))

    // Add the dependencies for Firebase products you want to use
    // When using the BoM, don't specify versions in Firebase dependencies
    implementation("com.google.firebase:firebase-analytics")
}

// Task to print the JDK version Gradle is using (keep for info if build proceeds)
tasks.register("printJdkVersion") {
    doLast {
        println("Gradle JDK version: " + System.getProperty("java.version"))
        println("Gradle JDK home: " + System.getProperty("java.home"))
    }
}
