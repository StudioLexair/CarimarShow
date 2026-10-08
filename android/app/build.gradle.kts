import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ══════════════════════════════════════════════════════════════════════════
//  Firmado de release
// ══════════════════════════════════════════════════════════════════════════
//
//  Se lee de `android/key.properties`, que **está en .gitignore**: las
//  credenciales de firmado nunca entran en el repositorio.
//
//  En CI ese archivo no existe en disco; el workflow lo materializa a partir
//  del secreto `ANDROID_KEYSTORE_BASE64` (ver .github/workflows/release.yml).
//
//  Si no hay key.properties, o el keystore que apunta no existe, se firma con
//  la clave de debug. Así `flutter build apk --release` sigue funcionando en
//  una máquina recién clonada en vez de fallar con un error críptico de Gradle.
// ══════════════════════════════════════════════════════════════════════════

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val releaseStorePath = keystoreProperties.getProperty("storeFile")
val releaseStoreFile = releaseStorePath?.let { rootProject.file(it) }
val hasReleaseSigning = releaseStoreFile != null && releaseStoreFile.exists()

if (keystorePropertiesFile.exists() && !hasReleaseSigning) {
    logger.warn(
        "key.properties existe pero el keystore no está en ${releaseStorePath}. " +
        "Se firmará con la clave de DEBUG: el APK no sirve para distribución."
    )
}

android {
    namespace = "com.sinflix.sinflix"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sinflix.sinflix"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                // El keystore se genera en PKCS12 (openssl), no en el formato
                // JKS legacy. Sin esta línea Java intenta leerlo como JKS.
                storeType = "PKCS12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Sin ofuscación agresiva: Flutter ya compila a código nativo AOT y
            // `minifyEnabled` sobre un proyecto Flutter aporta poco y rompe la
            // reflexión de algunos plugins. Se deja desactivado a propósito.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
