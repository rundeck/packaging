package org.rundeck.gradle

import java.util.jar.JarInputStream

import org.gradle.api.DefaultTask
import org.gradle.api.tasks.TaskAction
import org.gradle.api.Task
import org.gradle.api.tasks.*

class PackageTask extends DefaultTask {

    @Input
    String artifactPath

    @Input
    String packageVersion

    @Input
    String packageRelease

    @Input
    String packageName

    Task deb

    Task rpm

    @TaskAction
    doPackaging() {
        // deb.execute()
        // rpm.execute()
    }

    @Override
    public Task configure(Closure closure) {
        project.afterEvaluate({ -> afterProject()})

        super.configure(closure)

        configurePackaging()
        this
    }

    def afterProject() {
        println 'After!!!'
    }

    def configurePackaging() {
        project.pluginManager.apply('nebula.ospackage')

        def warContentDir = "$project.buildDir/warContents/$packageName"
        def cliDir = "$project.buildDir/cli/$packageName"

        def prepareTask = project.task("prepare-$packageName").doLast {
            project.copy {
                from project.zipTree(artifactPath)
                into warContentDir
            }

            def contentDir = cliDir
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
        bundle.baseName = 'rundeck'
        bundle.warContentDir = warContentDir
        bundle.rdBaseDir = "$project.buildDir/package"
        bundle.cliContentDir = "$project.buildDir/cli"

        def rdBaseDir = "/var/lib/rundeck"
        def rdConfDir = "/etc/rundeck"

        def sharedConfig = { it ->
            println 'shared'
            println it

            it.packageName = 'rundeck'
            // version = packageVersion
            it.release = packageRelease
            it.os = it.LINUX
            it.packageGroup = 'System'
            it.summary = "Rundeck"
            it.packageDescription = "Rundeck"
            it.packageName = packageName
            it.url = 'http://rundeck.com'
            it.vendor = 'Rundeck, Inc.'

            it.user = "rundeck"
            it.permissionGroup = "rundeck"

            it.into "$project.buildDir/packages"

            it.signingKeyId = project.findProperty('signingKeyId')
            it.signingKeyPassphrase = project.findProperty('signingPassword')
            it.signingKeyRingFile = project.findProperty('signingKeyRingFile')

            // Create Dirs
            it.directory("/etc/rundeck", 0750)
            it.directory("/var/log/rundeck", 0775)
            it.directory("/var/lib/rundeck", 0755)
            it.directory("/var/lib/rundeck/.ssh", 0700)
            it.directory("/var/lib/rundeck/bootstrap", 0755)
            it.directory("/var/lib/rundeck/cli", 0755)
            it.directory("/var/lib/rundeck/cli/lib", 0755)
            it.directory("/var/lib/rundeck/cli/bin", 0755)
            it.directory("/var/lib/rundeck/logs", 0755)
            it.directory("/var/lib/rundeck/data", 0755)
            it.directory("/var/lib/rundeck/work", 0755)
            it.directory("/var/lib/rundeck/libext", 0755)
            it.directory("/var/lib/rundeck/var", 0755)
            it.directory("/var/lib/rundeck/var/tmp", 0755)
            it.directory("/var/lib/rundeck/var/tmp/pluginJars", 0755)
            it.directory("/var/rundeck", 0755)
            it.directory("/var/rundeck/projects", 0755)
            it.directory("/tmp/rundeck", 1755)
            it.directory("/var/lib/rundeck/libext", 0755)

            it.from("lib/common/etc/rundeck") {
                fileType it.CONFIG | it.NOREPLACE
                fileMode 0640
                into "${rdConfDir}"
            }

            it.from("artifacts") {
                include "*.war"
                into "${rdBaseDir}/bootstrap"
            }

            it.from("${bundle.warContentDir}/WEB-INF/rundeck/plugins") {
                include "*.jar"
                include "*.zip"
                include "*.groovy"
                into "${rdBaseDir}/libext"
            }

            it.from("${bundle.cliContentDir}/bin") {
                into "$rdBaseDir/cli/bin"
            }

            it.from("${bundle.cliContentDir}/lib") {
                into "$rdBaseDir/cli/lib"
            }
            def tools = new File(bundle.cliContentDir, "bin").listFiles()*.name

            tools.each { tool ->
                it.link("/usr/bin/$tool", "$rdBaseDir/cli/bin/$tool")
            }
        }

        def debBuild = project.task("build-$packageName-deb", type: project.Deb, group: 'build') {
            dependsOn prepareTask

            sharedConfig(it)

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
    //        preInstall ""
            postInstall project.file("lib/deb/scripts/postinst")
            if (packageName =~ /cluster/) {
                postInstall project.file("lib/deb/scripts/postinst-cluster")
            }
            preUninstall "service rundeckd stop"
            postUninstall project.file("lib/deb/scripts/postrm")

            // Copy Files

            from("lib/deb/etc") {
                fileType CONFIG | NOREPLACE
                into "/etc"
            }
        }

        def rpmBuild = project.task("build-$packageName-rpm", type: project.Rpm, group: 'build') {
            dependsOn prepareTask

            sharedConfig(it)

            requires('chkconfig')
            requires('initscripts')
            requires("openssh")
            requires('openssl')

            // Install scripts
            preInstall project.file("lib/rpm/scripts/preinst.sh")
            postInstall project.file("lib/rpm/scripts/postinst.sh")
            if (packageName =~ /cluster/) {
                postInstall project.file("lib/rpm/scripts/postinst-cluster.sh")
            }
            preUninstall project.file("lib/rpm/scripts/preuninst.sh")
            postUninstall project.file("lib/rpm/scripts/postuninst.sh")

            // Copy Files
            from("lib/rpm/etc/rc.d/init.d/rundeckd") {
                fileMode 0755
                user = "root"
                permissionGroup = "root"
                into "/etc/rc.d/init.d"
            }

            from("lib/rpm/etc/rundeck") {
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