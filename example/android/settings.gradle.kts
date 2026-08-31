pluginManagement {
    val flutterSdkPath =
        java.util.Properties().run {
            file("local.properties").inputStream().use { load(it) }
            getProperty("flutter.sdk")
                ?: error("flutter.sdk not set in local.properties")
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.10.0"
}

include(":app")