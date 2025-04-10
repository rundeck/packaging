package org.rundeck.gradle

import org.gradle.api.DefaultTask
import org.gradle.api.Task
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.InputFile
import org.gradle.api.tasks.TaskAction
import org.redline_rpm.header.Flags

class PackageTask extends DefaultTask {

    @Input
    String packageName

    @Input
    String packageDescription

    @InputFile
    File artifact

    @Input
    String packageVersion

    @Input
    String packageRelease

    @InputDirectory
    File libDir

    @Internal
    String warContentDir

    @Internal
    Task deb

    @Internal
    Task rpm

    @Internal
    def rdConfDir = "/etc/rundeck"

    @Internal
    def rdBaseDir = "/var/lib/rundeck"

    @TaskAction
    doPackaging() {
        // deb.execute()
        // rpm.execute()
    }

    @Override
    public Task configure(Closure closure) {
        project.afterEvaluate({ -> afterProject()})

        super.configure(closure)

        warContentDir = "$project.buildDir/warContents/$packageName"

        configurePackaging()
        this
    }

    /** Called after project configuration **/
    def afterProject() {}

    /**
     * Only one ospackage can be defined and it applies globally.
     * We can build multiple packages in one go so apply our own config via lambda.
    */
    def applySharedConfig(delegate) {
        def providedPackageName = packageName
        def sharedConfig = {
            packageName = providedPackageName
            version = packageVersion
            release = packageRelease
            os = LINUX
            packageGroup = 'System'
            summary = "Rundeck"
            packageDescription = "Rundeck"
            url = 'http://rundeck.com'
            vendor = 'Rundeck, Inc.'

            user = "rundeck"
            permissionGroup = "rundeck"

            into "$project.buildDir/packages"

            signingKeyId = project.findProperty('signingKeyId')
            signingKeyPassphrase = project.findProperty('signingPassword')
            signingKeyRingFile = project.findProperty('signingKeyRingFile')

            // Create Dirs
            directory("/etc/rundeck", 0750, 'rundeck', 'rundeck')
            directory("/var/log/rundeck", 0775, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/.ssh", 0700, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/bootstrap", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/logs", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/data", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/work", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/libext", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/var", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/var/tmp", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/var/tmp/pluginJars", 0755, 'rundeck', 'rundeck')
            directory("/var/lib/rundeck/libext", 0755, 'rundeck', 'rundeck')

            from("$libDir/common/etc/rundeck") {
                into "${rdConfDir}"
                user 'rundeck'
                permissionGroup 'rundeck'
                fileType CONFIG | NOREPLACE
                fileMode 0640
            }

            from("artifacts") {
                into "${rdBaseDir}/bootstrap"
                user 'rundeck'
                permissionGroup 'rundeck'
                include "${artifact.name}"
            }

            from("$warContentDir/WEB-INF/rundeck/plugins") {
                into "${rdBaseDir}/libext"
                user 'rundeck'
                permissionGroup 'rundeck'
                include "*.jar"
                include "*.zip"
                include "*.groovy"
            }
        }

        sharedConfig.resolveStrategy = Closure.DELEGATE_FIRST
        sharedConfig.delegate = delegate
        sharedConfig()
    }

    def configurePackaging() {
        project.pluginManager.apply('nebula.ospackage')

        def prepareTask = project.task("prepare-$packageName") {
            inputs.file artifact.path

            outputs.dir warContentDir

        }
        prepareTask.doLast {
            project.copy {
                from project.zipTree(artifact.path)
                into warContentDir
            }

        }

        def bundle = [:]
        bundle.name = 'cluster'
        bundle.rdBaseDir = "$project.buildDir/package"

        def debBuild = project.task("build-$packageName-deb", type: project.Deb, group: 'build') {
            dependsOn prepareTask

            applySharedConfig(it)

            // Requirements
            requires('openssh-client')
            requires('java17-runtime-headless')
                    .or('java17-runtime')
            requires('adduser', '3.11', GREATER | EQUAL)
            requires('uuid-runtime')
            requires('openssl')

            configurationFile('/etc/init.d/rundeckd')

            def file = new File("$libDir/common/etc/rundeck")

            def processDir
            processDir = { File dir, String parent ->
                dir.listFiles().each { f ->
                    if (f.isDirectory())
                        processDir(f, "$parent/$f.name")
                    else
                        configurationFile("$parent/$f.name")
                }
            }
            processDir(file, '/etc/rundeck')

            // Install scripts
            postInstall project.file("$libDir/deb/scripts/postinst")
            if (packageName =~ /enterprise/) {
                replaces('rundeckpro-cluster', '3.0.9', Flags.LESS | Flags.EQUAL)
                conflicts('rundeckpro-cluster', '3.0.9', Flags.LESS | Flags.EQUAL)
                postInstall project.file("$libDir/deb/scripts/postinst-cluster")
            }
            preUninstall "service rundeckd stop"
            postUninstall project.file("$libDir/deb/scripts/postrm")

            // Copy Files

            from("$libDir/deb/etc") {
                into "/etc"
                fileType CONFIG | NOREPLACE
            }
        }

        def rpmBuild = project.task("build-$packageName-rpm", type: project.Rpm, group: 'build') {
            dependsOn prepareTask

            prefix('/var/lib/rundeck')
            prefix('/etc/rundeck')
            prefix('/usr/bin')
            prefix('/var/log/rundeck')
            prefix('/etc/rc.d/init.d')

            applySharedConfig(it)

            // Requirements
            requires('chkconfig')
            requires('initscripts')
            requires('openssh')
            requires('openssl')
            requires('java-17-headless')
                    .or('jre-17-headless')
                    .or('java-17')
                    .or('jre-17')

            // Install scripts
            preInstall project.file("$libDir/rpm/scripts/preinst.sh")
            postInstall project.file("$libDir/rpm/scripts/postinst.sh")
            if (packageName =~ /enterprise/) {
                obsoletes('rundeckpro-cluster', '3.0.9', Flags.EQUAL | Flags.LESS)
                postInstall project.file("$libDir/rpm/scripts/postinst-cluster.sh")
            } else {
                obsoletes('rundeck-config')
            }
            preUninstall project.file("$libDir/rpm/scripts/preuninst.sh")
            postUninstall project.file("$libDir/rpm/scripts/postuninst.sh")

            // Copy Files
            from("$libDir/rpm/etc/rc.d/init.d/rundeckd") {
                into "/etc/rc.d/init.d"
                user = "root"
                permissionGroup = "root"
                fileMode 0755
            }

            from("$libDir/rpm/etc/rundeck") {
                into "${rdConfDir}"
                user 'rundeck'
                permissionGroup 'rundeck'
                fileType CONFIG | NOREPLACE
                fileMode 0640
            }
        }

        rpm = rpmBuild
        deb = debBuild

        debBuild.getOutputs().each { it.getFiles().each {
            outputs.file it
        }}

        rpmBuild.getOutputs().each { it.getFiles().each {
            outputs.file it
        }}

        dependsOn rpm, deb
    }
}
