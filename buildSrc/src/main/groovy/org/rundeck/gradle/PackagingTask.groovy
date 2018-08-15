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
        deb.execute()
        rpm.execute()
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

        def prepareTask = project.task("prepare-$packageName").doLast {
            project.copy {
                from project.zipTree(artifactPath)
                into warContentDir
            }

            def contentDir = "$project.buildDir/cli"
            def cliLibs = new File(contentDir, 'lib')
            def cliBin = new File(contentDir, 'bin')
            def cliTmp = new File(contentDir, 'tmp')
            cliLibs.mkdirs()
            cliBin.mkdirs()
            cliTmp.mkdirs()
            def coreJar = project.fileTree("$project.buildDir/warContents") {
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
                    from new File("$project.buildDir/warContents", "WEB-INF/lib/" + lib)
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

        project.ospackage {
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

            from("common/etc/rundeck") {
                fileType CONFIG | NOREPLACE
                fileMode 0640
                into "${rdConfDir}"
            }

            from("artifacts") {
                include "*.war"
                into "${rdBaseDir}/bootstrap"
            }

            from("${bundle.warContentDir}/WEB-INF/rundeck/plugins") {
                include "*.jar"
                include "*.zip"
                include "*.groovy"
                into "${rdBaseDir}/libext"
            }

            from("${bundle.cliContentDir}/bin") {
                into "$rdBaseDir/cli/bin"
            }

            from("${bundle.cliContentDir}/lib") {
                into "$rdBaseDir/cli/lib"
            }
            def tools = new File(bundle.cliContentDir, "bin").listFiles()*.name

            tools.each { tool ->
                link("/usr/bin/$tool", "$rdBaseDir/cli/bin/$tool")
            }
        }

        def debBuild = project.task("build-$packageName-deb", type: project.Deb, group: 'build') {
            dependsOn prepareTask
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
            postInstall project.file("deb/scripts/postinst")
            if (packageName =~ /cluster/) {
                postInstall project.file("deb/scripts/postinst-cluster")
            }
            preUninstall "service rundeckd stop"
            postUninstall project.file("deb/scripts/postrm")

            // Copy Files

            from("deb/etc") {
                fileType CONFIG | NOREPLACE
                into "/etc"
            }
        }

        def rpmBuild = project.task("build-$packageName-rpm", type: project.Rpm, group: 'build') {
            dependsOn prepareTask

            requires('chkconfig')
            requires('initscripts')
            requires("openssh")
            requires('openssl')

            // Install scripts
            preInstall project.file("rpm/scripts/preinst.sh")
            postInstall project.file("rpm/scripts/postinst.sh")
            if (packageName =~ /cluster/) {
                postInstall project.file("rpm/scripts/postinst-cluster.sh")
            }
            preUninstall project.file("rpm/scripts/preuninst.sh")
            postUninstall project.file("rpm/scripts/postuninst.sh")

            // Copy Files
            from("rpm/etc/rc.d/init.d/rundeckd") {
                fileMode 0755
                user = "root"
                permissionGroup = "root"
                into "/etc/rc.d/init.d"
            }

            from("rpm/etc/rundeck") {
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
    }
}