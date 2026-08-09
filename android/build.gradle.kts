import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import com.android.build.api.dsl.LibraryExtension

group = "biz.cunning.cunning_document_scanner"
version = "3.0.0"

plugins {
    id("com.android.library")
}
val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

if (agpMajor < 9) {
    pluginManager.apply("org.jetbrains.kotlin.android")
}

configure<LibraryExtension> {
    namespace = "biz.cunning.cunning_document_scanner"
    compileSdk = 34

    // A library's resources are merged into the host application's resource table, and on a
    // name collision the application wins. Without a prefix an app declaring something as
    // ordinary as `<color name="black">` would silently restyle this plugin's scanner.
    // AGP flags any resource added here that does not carry the prefix.
    resourcePrefix = "cunning_"

    defaultConfig {
        minSdk = 21
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("test") {
            java.srcDir("src/test/kotlin")
        }
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}
plugins.withId("org.jetbrains.kotlin.android") {
    extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")
    testImplementation("junit:junit:4.13.2")
}