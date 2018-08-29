package org.rundeck.gradle

import java.util.jar.JarInputStream

import org.gradle.api.DefaultTask
import org.gradle.api.tasks.TaskAction
import org.gradle.api.Task
import org.gradle.api.tasks.*

class PackageTask extends DefaultTask {

    @Input
    String packageName

    @Input
    String packageDescription

    @Input
    String artifactPath

    @Input
    String packageVersion

    @Input
    String packageRelease

    @Input
    String libDir

    String warContentDir
    String cliContentDir

    Task deb

    Task rpm

    def rdConfDir = "/etc/rundeck"
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
        cliContentDir = "$project.buildDir/cli/$packageName"

        configurePackaging()
        this
    }

    /** Called after project configuration **/
    def afterProject() {}

    def applySharedConfig(delegate) {
        def sharedConfig = {
            packageName = 'rundeck'
            version = packageVersion
            release = packageRelease
            os = LINUX
            packageGroup = 'System'
            summary = "Rundeck"
            packageDescription = "Rundeck"
            packageName = packageName
            url = 'http://rundeck.com'
            vendor = 'Rundeck, Inc.'

            user = "rundeck"
            permissionGroup = "rundeck"

            into "$project.buildDir/packages"

            signingKeyId = project.findProperty('signingKeyId')
            signingKeyPassphrase = project.findProperty('signingPassword')
            signingKeyRingFile = project.findProperty('signingKeyRingFile')

            // Create Dirs
            directory("/etc/rundeck", 0750)
            directory("/var/log/rundeck", 0775)
            directory("/var/lib/rundeck", 0755)
            directory("/var/lib/rundeck/.ssh", 0700)
            directory("/var/lib/rundeck/bootstrap", 0755)
            directory("/var/lib/rundeck/cli", 0755)
            directory("/var/lib/rundeck/cli/lib", 0755)
            directory("/var/lib/rundeck/cli/bin", 0755)
            directory("/var/lib/rundeck/logs", 0755)
            directory("/var/lib/rundeck/data", 0755)
            directory("/var/lib/rundeck/work", 0755)
            directory("/var/lib/rundeck/libext", 0755)
            directory("/var/lib/rundeck/var", 0755)
            directory("/var/lib/rundeck/var/tmp", 0755)
            directory("/var/lib/rundeck/var/tmp/pluginJars", 0755)
            directory("/var/rundeck", 0755)
            directory("/var/rundeck/projects", 0755)
            directory("/tmp/rundeck", 1755)
            directory("/var/lib/rundeck/libext", 0755)

            from("$libDir/common/etc/rundeck") {
                fileType it.CONFIG | it.NOREPLACE
                fileMode 0640
                into "${rdConfDir}"
            }

            from("artifacts") {
                include "*.war"
                into "${rdBaseDir}/bootstrap"
            }

            from("$warContentDir/WEB-INF/rundeck/plugins") {
                include "*.jar"
                include "*.zip"
                include "*.groovy"
                into "${rdBaseDir}/libext"
            }

            from("$cliContentDir/bin") {
                into "$rdBaseDir/cli/bin"
            }

            from("$cliContentDir/lib") {
                into "$rdBaseDir/cli/lib"
            }
            def tools = new File(cliContentDir, "bin").listFiles()*.name

            tools.each { tool ->
                link("/usr/bin/$tool", "$rdBaseDir/cli/bin/$tool")
            }
        }

        sharedConfig.resolveStrategy = Closure.DELEGATE_FIRST
        sharedConfig.delegate = delegate
        sharedConfig()
    }

    def configurePackaging() {
        project.pluginManager.apply('nebula.ospackage')

        def prepareTask = project.task("prepare-$packageName") {
            inputs.file artifactPath

            outputs.dir cliContentDir
            outputs.dir warContentDir

        }
        prepareTask.doLast {
            project.copy {
                from project.zipTree(artifactPath)
                into warContentDir
            }

            def contentDir = cliContentDir
            def cliLibs = new File(contentDir, 'lib')
            def cliBin = new File(contentDir, 'bin')
            def cliTmp = new File(contentDir, 'tmp')
            cliLibs.mkdirs()
            cliBin.mkdirs()
            cliTmp.mkdirs()
            def coreJar = project.fileTree(warContentDir) {
                include "WEB-INF/lib/rundeck-core-*.jar"
            }.getSingleFile()
            project.copy {
                from coreJar
                into cliLibs
            }
            //get cli tool lib list from manifest of core jar
            def jar = new JarInputStream(coreJar.newInputStream())
            def list = jar.manifest.mainAttributes.getValue('Rundeck-Tools-Dependencies')
            list.split(' ').each { lib ->
                project.copy {
                    from new File(warContentDir, "WEB-INF/lib/" + lib)
                    into cliLibs
                }
            }

            //copy cli templates
            project.copy {
                from project.zipTree(coreJar)
                into cliTmp
                include 'com/dtolabs/rundeck/core/cli/templates/*'
                exclude '**/*.bat'
            }
            project.copy {
                from new File(cliTmp, 'com/dtolabs/rundeck/core/cli/templates')
                into cliBin
            }
        }

        def bundle = [:]
        bundle.name = 'cluster'
        bundle.rdBaseDir = "$project.buildDir/package"
        bundle.cliContentDir = "$project.buildDir/cli"

        def debBuild = project.task("build-$packageName-deb", type: project.Deb, group: 'build') {
            dependsOn prepareTask

            applySharedConfig(it)

            // Requirements
            requires('openssh-client')
            requires('java7-runtime').or('java7-runtime-headless').or('java8-runtime').or('java8-runtime-headless')
            requires('adduser', '3.11', GREATER | EQUAL)
            requires('uuid-runtime')
            requires('openssl')


            configurationFile('/etc/rundeck/rundeck-config.properties')
            configurationFile('/etc/rundeck/framework.properties')
            configurationFile('/etc/rundeck/profile')

            // Install scripts
            postInstall project.file("$libDir/deb/scripts/postinst")
            if (packageName =~ /cluster/) {
                postInstall project.file("$libDir/deb/scripts/postinst-cluster")
            }
            preUninstall "service rundeckd stop"
            postUninstall project.file("$libDir/deb/scripts/postrm")

            // Copy Files

            from("$libDir/deb/etc") {
                fileType CONFIG | NOREPLACE
                into "/etc"
            }
        }

        def rpmBuild = project.task("build-$packageName-rpm", type: project.Rpm, group: 'build') {
            dependsOn prepareTask

            applySharedConfig(it)

            requires('chkconfig')
            requires('initscripts')
            requires("openssh")
            requires('openssl')

            // Install scripts
            preInstall project.file("$libDir/rpm/scripts/preinst.sh")
            postInstall project.file("$libDir/rpm/scripts/postinst.sh")
            if (packageName =~ /cluster/) {
                postInstall project.file("$libDir/rpm/scripts/postinst-cluster.sh")
            }
            preUninstall project.file("$libDir/rpm/scripts/preuninst.sh")
            postUninstall project.file("$libDir/rpm/scripts/postuninst.sh")

            // Copy Files
            from("$libDir/rpm/etc/rc.d/init.d/rundeckd") {
                fileMode 0755
                user = "root"
                permissionGroup = "root"
                into "/etc/rc.d/init.d"
            }

            from("$libDir/rpm/etc/rundeck") {
                fileType CONFIG | NOREPLACE
                fileMode 0640
                into "${rdConfDir}"
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