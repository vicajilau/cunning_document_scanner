import org.jetbrains.kotlin.gradle.dsl.JvmTarget

group = "biz.cunning.cunning_document_scanner"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
}
val agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()

if (agpMajor < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

rootProject.allprojects {
    repositories {
        maven {
            url = uri("https://developer.huawei.com/repo/")
        }
    }
}

android {
    namespace = "biz.cunning.cunning_document_scanner"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/main/kotlin")
        }
    }
}
plugins.withId("org.jetbrains.kotlin.android") {
    extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0")
    compileOnly("com.huawei.hms:ml-computer-vision-documentskew:3.11.0.301")
    compileOnly("com.huawei.hms:ml-computer-vision-documentskew-model:3.7.0.301")
}