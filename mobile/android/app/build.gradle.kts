import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter pasa los --dart-define a Gradle como una lista separada por comas, cada uno en base64.
// La CNN de la ubre solo se empaqueta si la app se compila con --dart-define=UDDER_TRIAGE=true:
// apagada no se usa y sus ~0,85 MB dejarían el APK al borde del límite de 15 MB.
val udderTriageEnabled = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.filter { it.isNotBlank() }
    ?.map { String(Base64.getDecoder().decode(it)) }
    ?.contains("UDDER_TRIAGE=true")
    ?: false

android {
    namespace = "co.edu.ucc.agrovet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "co.edu.ucc.agrovet"
        // Android 7.0 o superior
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // La app usa solo el intérprete TFLite en CPU (libtensorflowlite_jni.so).
            // flutter_litert trae además el delegado de GPU y el runtime de la API CompiledModel
            // (libLiteRt.so); ninguno se carga.
            excludes += listOf(
                "**/libtensorflowlite_gpu_jni.so",
                "**/libLiteRtClGlAccelerator.so",
                "**/libLiteRt.so",
            )
            // Bibliotecas comprimidas dentro del APK: la descarga pesa menos de la mitad, a cambio
            // de que Android las descomprima al instalar. Importa más el plan de datos que el espacio.
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

// El plugin de Flutter copia los assets con tareas copyFlutterAssets<Variante>; con el triaje apagado
// se deja fuera el modelo de la ubre.
if (!udderTriageEnabled) {
    tasks.withType<Copy>().matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
        exclude("**/udder_cnn.tflite")
    }
}
