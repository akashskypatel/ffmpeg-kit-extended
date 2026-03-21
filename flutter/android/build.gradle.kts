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

// Execute configure.dart BEFORE the android block to ensure artifacts exist
val appRoot = project.rootProject.projectDir.parentFile
try {
    project.exec {
        workingDir = appRoot
        commandLine(
            "dart",
            "run",
            "ffmpeg_kit_extended_flutter:configure",
            "android",
            "--verbose",
            "--app-root=${appRoot}"
        )
    }
} catch (e: Exception) {
    logger.error("FFmpegKit: Failed to execute configure.dart. Ensure Dart SDK is in PATH.", e)
}

// Extract AAR during configuration phase so sourceSets can see the JNI libs
val currentPathFile = File(appRoot, ".dart_tool/ffmpeg_kit_extended_flutter/android/current_path.txt")
var extractedJniDir: File? = null

logger.lifecycle("FFmpegKit: appRoot = $appRoot")
logger.lifecycle("FFmpegKit: Looking for current_path.txt at ${currentPathFile.absolutePath}")
logger.lifecycle("FFmpegKit: current_path.txt exists = ${currentPathFile.exists()}")

if (currentPathFile.exists()) {
    val rawPath = currentPathFile.readText().trim()
    logger.lifecycle("FFmpegKit: current_path.txt content = '$rawPath'")

    // Resolve relative paths against appRoot
    val aarFile = if (File(rawPath).isAbsolute) File(rawPath) else File(appRoot, rawPath)
    logger.lifecycle("FFmpegKit: Resolved AAR path = ${aarFile.absolutePath}")
    logger.lifecycle("FFmpegKit: AAR file exists = ${aarFile.exists()}")

    if (aarFile.exists() && aarFile.name.endsWith(".aar")) {
        val extractDir = File(aarFile.parentFile, "extracted_aar_libs")

        if (!extractDir.exists() || !File(extractDir, "jni").exists()) {
            logger.lifecycle("FFmpegKit: Extracting AAR to $extractDir ...")
            extractDir.mkdirs()

            copy {
                from(zipTree(aarFile))
                into(extractDir)
            }

            logger.lifecycle("FFmpegKit: Extraction complete. Contents: ${extractDir.listFiles()?.map { it.name }}")
        }

        val jniDir = File(extractDir, "jni")
        logger.lifecycle("FFmpegKit: jni dir exists = ${jniDir.exists()}")
        if (jniDir.exists()) {
            jniDir.walkTopDown().filter { it.isFile }.forEach {
                logger.lifecycle("FFmpegKit:   Found native lib: ${it.relativeTo(jniDir)}")
            }
            extractedJniDir = jniDir
        }
    }
} else {
    logger.warn("FFmpegKit: current_path.txt not found!")
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

            if (extractedJniDir != null) {
                logger.lifecycle("FFmpegKit: Adding JNI libs srcDir -> $extractedJniDir")
                jniLibs.srcDir(extractedJniDir!!)
            } else {
                logger.warn("FFmpegKit: No JNI directory available to add to sourceSets!")
            }
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
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}