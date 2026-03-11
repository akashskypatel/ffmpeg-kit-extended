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

android {
    namespace = "com.akashskypatel.ffmpeg_kit_extended_flutter"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            
            val currentPathFile = File(project.projectDir.parentFile, ".dart_tool/ffmpeg_kit_extended_flutter/android/current_path.txt")
            if (currentPathFile.exists()) {
                val extractedPath = currentPathFile.readText().trim()
                val jniDir = File(extractedPath, "jni")
                
                if (jniDir.exists()) {
                    jniLibs.srcDir(jniDir)
                }
            }
        }
        
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 26
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

val pluginRoot = project.projectDir.parentFile
try {
    project.exec {
        workingDir = pluginRoot
        commandLine(
            "dart", 
            "run", 
            "ffmpeg_kit_extended_flutter:configure", 
            "android", 
            "--verbose"
        )
    }
} catch (e: Exception) {
    logger.error("FFmpegKit: Failed to execute configure.dart. Ensure Dart SDK is in PATH.", e)
}

dependencies {
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")

    val currentPathFile = File(project.projectDir.parentFile, ".dart_tool/ffmpeg_kit_extended_flutter/android/current_path.txt")
    if (currentPathFile.exists()) {
        val extractedPath = currentPathFile.readText().trim()
        val classesJar = File(extractedPath, "classes.jar")
        
        if (classesJar.exists()) {
            implementation(files(classesJar))
        }
    }
}