import java.io.File
import java.util.Properties

group = "com.akashskypatel.ffmpeg_kit_extended_flutter"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
}

val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

if (agpMajor < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
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

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin", "src/java")
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

project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
