buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.4")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Fix for plugins that expect the 'flutter' property to be available (e.g. app_links)
// and ensuring compileSdkVersion is high enough to avoid 'lStar' resource errors.
subprojects {
    afterEvaluate {
        if (project.plugins.hasPlugin("com.android.library") || project.plugins.hasPlugin("com.android.application")) {
            val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            android?.apply {
                compileSdkVersion(36)
                defaultConfig {
                    targetSdkVersion(34)
                }
                
                // v2.8.3: Fix for packages missing namespace in Gradle 8+
                if (project.name == "optimization_battery") {
                    namespace = "com.example.optimization_battery"
                }
            }

            if (!project.hasProperty("flutter")) {
                project.extensions.extraProperties.set("flutter", mapOf(
                    "compileSdkVersion" to 36,
                    "targetSdkVersion" to 34,
                    "minSdkVersion" to 21
                ))
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}