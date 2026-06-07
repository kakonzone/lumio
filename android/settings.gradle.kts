// Flutter plugins ship legacy buildscript { ext.kotlin_version = '2.1.x' } blocks.
// Register before any project (including plugins) is configured.
val kotlinVersion = "2.1.0"

gradle.beforeProject {
    ext.set("kotlin_version", kotlinVersion)
    buildscript {
        configurations.classpath {
            resolutionStrategy {
                force("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
                eachDependency {
                    if (requested.group == "org.jetbrains.kotlin") {
                        useVersion(kotlinVersion)
                        because("Align Kotlin compiler with app module ($kotlinVersion)")
                    }
                }
            }
        }
    }
    configurations.configureEach {
        resolutionStrategy {
            force("org.jetbrains.kotlin:kotlin-stdlib:$kotlinVersion")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlinVersion")
            force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:$kotlinVersion")
            force("org.jetbrains.kotlin:kotlin-stdlib-common:$kotlinVersion")
        }
    }
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    resolutionStrategy {
        eachPlugin {
            when (requested.id.id) {
                "org.jetbrains.kotlin.android",
                "kotlin-android",
                "org.jetbrains.kotlin.jvm",
                "org.jetbrains.kotlin.multiplatform",
                -> useVersion("2.1.0")
            }
        }
    }
    
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
    id("com.google.firebase.crashlytics") version "3.0.3" apply false
}

include(":app")
