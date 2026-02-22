import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.newstube"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.newstube"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ Gera APK/AAB compatível com qualquer arquitetura Android suportada
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
        getByName("debug") {
            // padrão
        }

        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")

            // ✅ Mantém minify (R8) funcionando sem quebrar o extractor/Rhino/Jsoup
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Flavors (Kotlin DSL correto)
    flavorDimensions += "flavor"

    productFlavors {
        create("staging") {
            dimension = "flavor"
        }
    }
}

dependencies {
    // NewPipe Extractor (usado pelo MethodChannel NativeExtractor)
    implementation("com.github.teamnewpipe:newpipeextractor:v0.25.2")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // ✅ Corrige "Missing class com.google.re2j.*" (referência opcional do Jsoup)
    implementation("com.google.re2j:re2j:1.7")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.2")
}

flutter {
    source = "../.."
}
