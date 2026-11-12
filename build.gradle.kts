plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.qrstudio.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    defaultConfig {
        applicationId = "com.qrstudio.app"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release {
            // Test-only signing so the optimized APK can be installed directly.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    dependencies {
        implementation("com.google.android.gms:play-services-code-scanner:16.1.0")
    }
}
flutter { source = "../.." }
