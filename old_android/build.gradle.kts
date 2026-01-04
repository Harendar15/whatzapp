buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // AGP - match the plugin version in settings.gradle
        classpath "com.android.tools.build:gradle:8.7.0"

        // Kotlin Gradle plugin (must match plugins version above)
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0"

        // Google services if you use firebase
        classpath "com.google.gms:google-services:4.4.2"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/* Shared build directory (optional) */
rootProject.buildDir = "../build"

subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
