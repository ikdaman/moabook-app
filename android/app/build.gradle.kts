import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProps = Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyProps.load(keyPropsFile.inputStream())
}

android {
    namespace = "project.side.ikdaman"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            storeFile = rootProject.file("release.keystore")
            storePassword = keyProps.getProperty("KEYSTORE_PASSWORD", "")
            keyAlias = keyProps.getProperty("KEY_ALIAS", "")
            keyPassword = keyProps.getProperty("KEY_PASSWORD", "")
        }
    }

    defaultConfig {
        applicationId = "project.side.ikdaman"
        minSdk = 29
        targetSdk = 36
        // Flutter Gradle plugin 이 pubspec.yaml 의 version: X.Y.Z+N 으로부터
        // 자동 주입한다. (versionName = X.Y.Z, versionCode = N)
        // hardcode 하면 pubspec bump 가 무시되어 Play Store 업로드 시
        // versionCode 충돌/다운그레이드 오류를 유발한다.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["KAKAO_APP_KEY"] = keyProps.getProperty("KAKAO_APP_KEY", "")
        buildConfigField("String", "GOOGLE_CLIENT_ID", "\"${keyProps.getProperty("GOOGLE_CLIENT_ID", "")}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("androidx.credentials:credentials:1.5.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    implementation("androidx.core:core-ktx:1.13.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")


    testImplementation("junit:junit:4.13.2")
    testImplementation("io.mockk:mockk:1.13.12")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}
