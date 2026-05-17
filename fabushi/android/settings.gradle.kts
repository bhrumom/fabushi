pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    resolutionStrategy {
        eachPlugin {
            if (requested.id.id == "com.google.gms.google-services") {
                useModule("com.google.gms:google-services:${requested.version}")
            }
        }
    }

    repositories {
        val preferOfficialReposInCi = System.getenv("GITHUB_ACTIONS") == "true" || System.getenv("CI") == "true"
        if (preferOfficialReposInCi) {
            google()
            mavenCentral()
            gradlePluginPortal()
        } else {
            // Keep local and regional builds mirror-first, but let CI avoid flaky mirror metadata.
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/central") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
            maven { url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/") }
            google()
            mavenCentral()
            gradlePluginPortal()
        }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        val preferOfficialReposInCi = System.getenv("GITHUB_ACTIONS") == "true" || System.getenv("CI") == "true"
        val flutterGlLocalMavenRepo = File(rootDir, "../lib/packages/flutter_gl/android/libs/maven")

        // Keep the vendored threeegl coordinate visible from settings because app builds prefer settings repositories.
        maven { url = flutterGlLocalMavenRepo.toURI() }
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }

        if (preferOfficialReposInCi) {
            google()
            mavenCentral()
        } else {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/central") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
            maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
            maven { url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/") }
            google()
            mavenCentral()
        }
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")