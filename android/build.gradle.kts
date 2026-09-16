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

// Raise `compileSdk` and the Java level on every plugin module.
//
// flutter_plugin_android_lifecycle publishes AAR metadata requiring API 36,
// while its consumers (image_picker, file_picker) still declare an older
// compileSdk of their own, so their `checkAarMetadata` task fails. The
// override must be applied per-subproject because each plugin brings its own
// android block; setting it on `:app` alone is not enough.
//
// This must be registered BEFORE the `evaluationDependsOn(":app")` block
// below: that call forces subprojects to evaluate, and `afterEvaluate` cannot
// be added to an already-evaluated project.
//
// Remove once the plugins ship with compileSdk 36 or later.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            if (androidExtension is com.android.build.gradle.BaseExtension) {
                val declared = androidExtension.compileSdkVersion
                    ?.substringAfter("android-")
                    ?.toIntOrNull()
                if (declared == null || declared < 36) {
                    androidExtension.compileSdkVersion(36)
                }
                androidExtension.compileOptions.apply {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
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
