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

// 在所有子工程（含插件）评估完成后再覆盖 compileSdk = 36，
// 以满足 file_picker 8 等插件对 SDK 36 的要求（必须在 evaluationDependsOn 之前注册）。
subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.api.dsl.CommonExtension>()?.apply {
            compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
