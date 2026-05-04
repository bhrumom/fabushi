val preferOfficialRepositories = System.getenv("GITHUB_ACTIONS") == "true"

fun org.gradle.api.artifacts.dsl.RepositoryHandler.addFabushiMirrorRepositories() {
    maven { url = uri("https://maven.aliyun.com/repository/google") }
    maven { url = uri("https://maven.aliyun.com/repository/central") }
    maven { url = uri("https://maven.aliyun.com/repository/public") }
    maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
    maven { url = uri("https://mirrors.cloud.tencent.com/nexus/repository/maven-public/") }
}

fun org.gradle.api.artifacts.dsl.RepositoryHandler.addFabushiOfficialRepositories(includeGradlePluginPortal: Boolean = false) {
    google()
    mavenCentral()
    if (includeGradlePluginPortal) {
        gradlePluginPortal()
    }
}

fun org.gradle.api.artifacts.dsl.RepositoryHandler.configureFabushiRepositories(includeGradlePluginPortal: Boolean = false) {
    if (preferOfficialRepositories) {
        // GitHub-hosted runners can reach upstream Maven reliably, so prefer it before the regional mirrors.
        addFabushiOfficialRepositories(includeGradlePluginPortal)
        addFabushiMirrorRepositories()
        return
    }

    // Local and regional builds still keep the mirrors first to tolerate blocked upstream access.
    addFabushiMirrorRepositories()
    addFabushiOfficialRepositories(includeGradlePluginPortal)
}

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
        configureFabushiRepositories(includeGradlePluginPortal = true)
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
        maven { url = uri("https://jitpack.io") }
        configureFabushiRepositories()
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