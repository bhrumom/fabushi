val preferOfficialRepositories = System.getenv("GITHUB_ACTIONS") == "true"

fun org.gradle.api.artifacts.dsl.RepositoryHandler.addFabushiBuildMirrors() {
    maven { url = uri("https://maven.aliyun.com/repository/google") }
    maven { url = uri("https://maven.aliyun.com/repository/central") }
    maven { url = uri("https://maven.aliyun.com/repository/public") }
    maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin") }
}

fun org.gradle.api.artifacts.dsl.RepositoryHandler.addFabushiBuildUpstreamRepositories() {
    google()
    mavenCentral()
}

fun org.gradle.api.artifacts.dsl.RepositoryHandler.configureFabushiBuildscriptRepositories() {
    if (preferOfficialRepositories) {
        addFabushiBuildUpstreamRepositories()
        addFabushiBuildMirrors()
        return
    }

    addFabushiBuildMirrors()
    addFabushiBuildUpstreamRepositories()
}

buildscript {
    repositories {
        configureFabushiBuildscriptRepositories()
    }
}

allprojects {
    buildscript {
        repositories {
            configureFabushiBuildscriptRepositories()
        }
    }
}

// 全局覆盖 CMake 版本，使用已安装的 3.22.1
subprojects {
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            val android = extensions.getByName("android") as com.android.build.gradle.BaseExtension
            android.externalNativeBuild.cmake.version = "3.22.1"
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}