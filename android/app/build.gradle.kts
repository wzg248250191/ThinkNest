plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.example.think_nest"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tianChen.thinkNest"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 关键逻辑：未配置 key.properties 时，为了不阻断本地/CI 构建，release 暂时回退到 debug 签名；
            // 配置 key.properties 后会自动使用 release 签名生成正式包。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // 关键：media_store_plus 在 Android 侧使用 GSON，若后续开启 R8/混淆，需要保留反射相关类成员。
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

val releaseApkNamePrefixProvider = providers.provider {
    val versionName = android.defaultConfig.versionName ?: "0.0.0"
    val versionCode = android.defaultConfig.versionCode ?: 0
    "思巢-成长之光-$versionName+$versionCode"
}

tasks.register<Copy>("syncReleaseApkToFlutterApkDir") {
    val androidApkDir = rootProject.layout.buildDirectory.dir("app/outputs/apk/release")
    val flutterApkDir = rootProject.layout.buildDirectory.dir("app/outputs/flutter-apk")
    from(androidApkDir)
    include("*.apk")
    include("output-metadata.json")
    into(flutterApkDir)
}

tasks.register<Copy>("copyReleaseApkWithCustomName") {
    val flutterApkDir = rootProject.layout.buildDirectory.dir("app/outputs/flutter-apk")
    dependsOn("syncReleaseApkToFlutterApkDir")
    from(flutterApkDir)
    include("*release*.apk")
    into(flutterApkDir)
    rename { originalName ->
        val prefix = releaseApkNamePrefixProvider.get()
        val abi = Regex("^app-(.+)-release\\.apk$").matchEntire(originalName)?.groupValues?.getOrNull(1)
        val abiSuffix = if (abi.isNullOrBlank()) "" else "-$abi"
        "$prefix$abiSuffix.apk"
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy("syncReleaseApkToFlutterApkDir", "copyReleaseApkWithCustomName")
}
