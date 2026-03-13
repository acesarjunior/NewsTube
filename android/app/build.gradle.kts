plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.newstube"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.newstube"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    flavorDimensions += "flavor"

    productFlavors {
        create("staging") {
            dimension = "flavor"
        }
    }
}

dependencies {
    implementation("com.github.teamnewpipe:newpipeextractor:v0.25.2")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("com.google.re2j:re2j:1.7")
    implementation("com.google.mlkit:genai-proofreading:1.0.0-beta1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.2")
}

flutter {
    source = "../.."
}
