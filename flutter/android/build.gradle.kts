import java.io.File
import java.util.Properties

group = "com.akashskypatel.ffmpeg_kit_extended_flutter"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

fun resolveStagedClassesJar(): File? {
    val appRoot = project.rootProject.projectDir.parentFile
    val propsFile = File(appRoot, ".dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/android_config/paths.properties")
    
    if (!propsFile.exists()) {
        logger.warn("FFmpegKit: paths.properties not found at ${propsFile.absolutePath}. This is expected on the first build.")
        return null
    }

    val props = Properties()
    propsFile.inputStream().use { props.load(it) }
    val path = props.getProperty("classes_jar") ?: return null
    
    val jarFile = File(path)
    return if (jarFile.exists()) jarFile else null
}

android {
    namespace = "com.akashskypatel.ffmpeg_kit_extended_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }

        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 26
        externalNativeBuild {
            cmake {
                arguments("-DANDROID_STL=c++_shared")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = File(projectDir, "src/main/cpp/CMakeLists.txt")
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    // Reference the absolute path directly
    val appRoot = project.rootProject.projectDir.parentFile
    logger.info("FFmpegKit: App root is ${appRoot.absolutePath}")
    val stagedJarPath = "${appRoot}/.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/android_config/classes.jar"
    
    // Use files() directly. Gradle will check for the file at execution time.
    implementation(files(stagedJarPath))
}