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

subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ FORCER compileSdk = 36 POUR TOUS LES SOUS-PROJETS (PLUGINS), SAUF "app"
subprojects {
    if (project.name == "app") return@subprojects

    afterEvaluate {
        if (project.hasProperty("android")) {
            try {
                val android = project.extensions.getByName("android")
                when (android) {
                    is com.android.build.api.dsl.LibraryExtension -> {
                        android.compileSdk = 36
                    }
                    is com.android.build.api.dsl.ApplicationExtension -> {
                        android.compileSdk = 36
                    }
                }
            } catch (e: Exception) {
                // Ignorer les erreurs si le plugin n'a pas la configuration android
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}