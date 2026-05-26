import org.gradle.api.Project
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.File
import java.io.FileInputStream
import java.nio.charset.StandardCharsets
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
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

android {
    namespace = "com.kakonzone.lumio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.kakonzone.lumio"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Sync native manifest key with Dart String.fromEnvironment('LEVELPLAY_APP_KEY').
        resValue("string", "levelplay_app_key", levelPlayAppKey)
        manifestPlaceholders["levelPlayAppKey"] = levelPlayAppKey

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-O3", "-fvisibility=hidden", "-DNDEBUG")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    signingConfigs {
        create("release") {
            val store = resolveReleaseStoreFile()
            if (store != null) {
                storeFile = store
                storePassword = releaseSigningValue("storePassword", "RELEASE_STORE_PASSWORD")
                keyAlias = releaseSigningValue("keyAlias", "RELEASE_KEY_ALIAS")
                keyPassword = releaseSigningValue("keyPassword", "RELEASE_KEY_PASSWORD")
            } else {
                logger.warn(
                    "Release keystore missing — set android/key.properties or RELEASE_* env / dart-define.",
                )
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig =
                if (releaseSigning.storeFile != null) releaseSigning
                else signingConfigs.getByName("debug")
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
        }
    }

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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
    implementation("com.google.android.gms:play-services-appset:16.0.2")
    implementation("com.google.android.gms:play-services-ads-identifier:18.0.1")
    implementation("com.google.android.gms:play-services-basement:18.3.0")
}
