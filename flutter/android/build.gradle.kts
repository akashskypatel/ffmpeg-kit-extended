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

// FFmpegKit Java/Kotlin classes are staged by hook/build.dart.
// We locate the path via the generated properties file in .dart_tool.
val appRoot = project.rootProject.projectDir.parentFile
val propsFile = File(appRoot, ".dart_tool/ffmpeg_kit_extended_flutter/shared/android_config/paths.properties")
var classesJar: File? = null

if (propsFile.exists()) {
    val props = java.util.Properties()
    propsFile.inputStream().use { props.load(it) }
    val path = props.getProperty("classes_jar")
    if (path != null) {
        classesJar = File(path)
        logger.lifecycle("FFmpegKit: Found classes.jar via properties: ${classesJar!!.absolutePath}")
    }
}

if (classesJar == null || !classesJar!!.exists()) {
    logger.warn("FFmpegKit: ffmpegkit-classes.jar not found.")
    logger.warn("FFmpegKit: It should be staged by hook/build.dart during 'flutter build' or 'dart run'.")
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
            path("src/main/cpp/CMakeLists.txt")
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
    // Include the staged classes.jar for compile-time access to FFmpegKit's Java API.
    classesJar?.let { 
        if (it.exists()) {
            implementation(files(it)) 
        }
    }
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
