import org.gradle.api.Project
import org.gradle.api.GradleException
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.File
import java.io.FileInputStream
import java.nio.charset.StandardCharsets
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") version "2.1.0"
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.android.play.integrity") version "1.1.0"
}

if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
} else {
    logger.warn(
        "google-services.json missing — Firebase Analytics/Crashlytics disabled until added to android/app/",
    )
}

/** Parses `--dart-define=KEY=VALUE` entries passed by Flutter into Gradle. */
fun parseDartDefines(project: Project): Map<String, String> {
    if (!project.hasProperty("dart-defines")) return emptyMap()
    val raw = project.property("dart-defines") as String
    if (raw.isEmpty()) return emptyMap()
    return raw.split(",").mapNotNull { encoded ->
        try {
            val decoded = String(Base64.getDecoder().decode(encoded), StandardCharsets.UTF_8)
            val eq = decoded.indexOf('=')
            if (eq <= 0) null else decoded.substring(0, eq) to decoded.substring(eq + 1)
        } catch (_: IllegalArgumentException) {
            null
        }
    }.toMap()
}

val dartDefines = parseDartDefines(project)

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use { localProperties.load(it) }
}

val levelPlayAppKey =
    localProperties.getProperty("LEVELPLAY_APP_KEY")?.takeIf { it.isNotEmpty() }
        ?: System.getenv("LEVELPLAY_APP_KEY")?.takeIf { it.isNotEmpty() }
        ?: dartDefines["LEVELPLAY_APP_KEY"]?.takeIf { it.isNotEmpty() }
        ?: ""

if (levelPlayAppKey.isEmpty()) {
    logger.warn(
        "LEVELPLAY_APP_KEY unset — set android/local.properties, env, or --dart-define.",
    )
}

val keystoreProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    FileInputStream(keyPropertiesFile).use { keystoreProperties.load(it) }
}

fun releaseSigningValue(
    propKey: String,
    envKey: String,
    dartKey: String = envKey,
): String? =
    keystoreProperties.getProperty(propKey)?.takeIf { it.isNotEmpty() }
        ?: System.getenv(envKey)?.takeIf { it.isNotEmpty() }
        ?: dartDefines[dartKey]?.takeIf { it.isNotEmpty() }

fun resolveReleaseStoreFile(): File? {
    val path = releaseSigningValue("storeFile", "RELEASE_STORE_FILE") ?: return null
    val file = if (File(path).isAbsolute) File(path) else rootProject.file(path)
    return file.takeIf { it.exists() }
}

val releaseBuildAbortMessage =
    "RELEASE BUILD ABORTED: key.properties missing or storeFile null. See docs/RELEASE_SIGNING.md"

val isReleaseBuildRequested = gradle.startParameter.taskNames.any { task ->
    task.contains("release", ignoreCase = true)
}

/** Local APK size check only (`tool/build_size_apk.sh`). Production release still fail-closed. */
val localSizeCheck =
    project.findProperty("LUMIO_LOCAL_SIZE_CHECK")?.toString() == "true"

fun releaseSigningReady(): Boolean {
    val store = resolveReleaseStoreFile()
    val storePass = releaseSigningValue("storePassword", "RELEASE_STORE_PASSWORD")
    val alias = releaseSigningValue("keyAlias", "RELEASE_KEY_ALIAS")
    val keyPass = releaseSigningValue("keyPassword", "RELEASE_KEY_PASSWORD")
    return store != null &&
        !storePass.isNullOrBlank() &&
        !alias.isNullOrBlank() &&
        !keyPass.isNullOrBlank()
}

android {
    namespace = "com.kakonzone.lumio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    androidResources {
        localeFilters += listOf("en")
        // generateLocaleConfig = true  // Disabled due to build issues
    }

    defaultConfig {
        applicationId = "com.kakonzone.lumio"
        // Android 5.0 Lollipop (API 21)+ — release: flutter build apk --split-per-abi (32 + 64 separate).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // ABI splits are configured in splits block below

        // Sync native manifest key with Dart String.fromEnvironment('LEVELPLAY_APP_KEY').
        resValue("string", "levelplay_app_key", levelPlayAppKey)
        manifestPlaceholders["levelPlayAppKey"] = levelPlayAppKey

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-O3", "-fvisibility=hidden", "-DNDEBUG", "-ffunction-sections", "-fdata-sections")
                cFlags += listOf("-O3", "-fvisibility=hidden", "-DNDEBUG", "-ffunction-sections", "-fdata-sections")
                arguments += listOf("-DANDROID_STL=c++_shared", "-DANDROID_ARM_NEON=TRUE")
            }
        }

        // ABI: use `flutter build apk --split-per-abi --target-platform=android-arm64`
        // Do not set ndk.abiFilters here — conflicts with Flutter split-per-abi.
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    signingConfigs {
        getByName("debug") {
            // API 21–23 (Android 5–6) require JAR (v1) signatures or install → Parse error.
            enableV1Signing = true
            enableV2Signing = true
        }
        create("release") {
            enableV1Signing = true
            enableV2Signing = true
            val store = resolveReleaseStoreFile()
            val storePass = releaseSigningValue("storePassword", "RELEASE_STORE_PASSWORD")
            val alias = releaseSigningValue("keyAlias", "RELEASE_KEY_ALIAS")
            val keyPass = releaseSigningValue("keyPassword", "RELEASE_KEY_PASSWORD")

            if (store != null && !storePass.isNullOrBlank() && !alias.isNullOrBlank() && !keyPass.isNullOrBlank()) {
                storeFile = store
                storePassword = storePass
                keyAlias = alias
                keyPassword = keyPass
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (releaseSigningReady()) {
                signingConfigs.getByName("release")
            } else if (System.getenv("LUMIO_LOCAL_SIZE_CHECK") == "true") {
                signingConfigs.getByName("debug")
            } else {
                throw GradleException(releaseBuildAbortMessage)
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            ndk {
                debugSymbolLevel = "NONE"
            }
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Enable app bundle for Play Store (smaller download size)
    bundle {
        language {
            enableSplit = false
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }

    // Enable R8 full mode for better optimization
    buildFeatures {
        buildConfig = true
    }

    // R8 full mode configuration
    buildTypes {
        release {
            signingConfig = if (releaseSigningReady()) {
                signingConfigs.getByName("release")
            } else if (System.getenv("LUMIO_LOCAL_SIZE_CHECK") == "true") {
                signingConfigs.getByName("debug")
            } else {
                throw GradleException(releaseBuildAbortMessage)
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            ndk {
                debugSymbolLevel = "NONE"
            }
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Further optimization: compress native libraries and remove unused
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
        resources {
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/*.kotlin_module",
                "META-INF/INDEX.LIST",
                "META-INF/io.netty.versions.properties",
                "**/*.proto",
                "META-INF/*.version",
                "META-INF/androidx.*",
                "META-INF/com.google.*",
                "META-INF/services/**",
                "kotlin/**",
                "kotlin_module/**",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
            )
        }
    }

    // Per-ABI APKs: use `flutter build apk --release --split-per-abi` (see tool/build_release_apk.sh).
    // Gradle abi splits stay off — Flutter split-per-abi avoids ndk.abiFilters conflicts.

}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("com.google.android.gms:play-services-appset:16.0.2")
    implementation("com.google.android.gms:play-services-ads-identifier:18.0.1")
    implementation("com.google.android.gms:play-services-basement:18.3.0")
    // Exclude unused transitive dependencies to reduce size
    implementation("com.google.android.gms:play-services-base:18.5.0") {
        exclude(group = "com.google.android.gms", module = "play-services-tasks")
    }
}
