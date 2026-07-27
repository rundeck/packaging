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

    // Grails 7 requires Java 17+; system requirements say 17-25 are supported.
    // Newest-first: see addDebJavaRequirement() for why order matters there.
    static final List<Integer> SUPPORTED_JAVA_MAJOR_VERSIONS = [25, 21, 17]

    /**
     * RPM's classic dependency model is AND-only - there's no per-Dependency
     * OR/alternative semantics. The newer rich/boolean dependency syntax
     * (`Requires: (A or B or C)`, supported by rpm/dnf on RHEL 8+ since rpm
     * 4.13) is the only way to express "one of several packages", and
     * redline-rpm (this plugin's RPM writer) has no typed API for it - but it
     * does write whatever literal string is passed as the dependency name
     * verbatim. `.or()` chaining (used for deb, see addDebJavaRequirement) is
     * silently dropped for RPM: RpmCopyAction.addDependency only reads
     * packageName/flag/version off the *first* Dependency, never its
     * `.alternative` chain (confirmed by inspecting a built RPM's raw
     * REQUIRENAME header - only the first name ever appeared, regardless of
     * how many `.or()` calls were chained).
     */
    static String rpmJavaHeadlessRequirement(List<Integer> majorVersions = SUPPORTED_JAVA_MAJOR_VERSIONS) {
        def names = majorVersions.collectMany { v -> ["java-${v}-headless", "jre-${v}-headless", "java-${v}", "jre-${v}"] }
        "(${names.join(' or ')})"
    }

    /**
     * Debian's OpenJDK packages provide java<N>-runtime(-headless) virtual
     * packages by convention, and `.or()` chaining works correctly here
     * (unlike rpm - see rpmJavaHeadlessRequirement). List newest-first:
     * apt/dpkg pick the first satisfiable alternative in list order, not
     * whichever is already installed, so oldest-first can pull in an
     * unneeded older JDK alongside a newer one that's already present
     * (harmless - both coexist and install still succeeds - but wasteful).
     */
    static void addDebJavaRequirement(delegate, List<Integer> majorVersions = SUPPORTED_JAVA_MAJOR_VERSIONS) {
        def names = majorVersions.collectMany { v -> ["java${v}-runtime-headless", "java${v}-runtime"] }
        def dep = delegate.requires(names[0])
        names.drop(1).each { dep = dep.or(it) }
    }

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
        project.pluginManager.apply('com.netflix.nebula.ospackage')

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
            addDebJavaRequirement(it)
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
            requires(rpmJavaHeadlessRequirement())

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
