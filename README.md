Rundeck DEB/RPM Packaging
=========================

Consolidated deb and rpm packaging and signing.

## Usage

### Package

> NOTE: Create a directory named `artifacts` in the root directory and place the built Rundeck WAR files there.  
> The build parses version information out of the file names, so the names matter!

> NOTE: `-PlibsDir` should point to the `Rundeck oss packaging/lib` directory.
```
./gradlew \
            -PpackageRelease=$RELEASE_NUM \
            -PlibsDir=../lib \
            clean packageArtifacts
```

**Inputs:**  
`artifacts/*.war`

**Outputs:**  
`build/distributions/*.{deb,rpm}`

### Sign
> **NOTE:** The redline Java rpm library used by ospackage will not sign
with our key lengh(stack overflow). For the reason we go ahead and utilize
expect for signing both rpm and deb packages.

With the proper envars exported:
```bash
bash packaging/scripts/sign-packages.sh
```

### Publish
> **NOTE:** The Bintray Gradle plugin has few rough edges due to its
implementation. Among them, only one package upload per project appears
to work. We run the build once per package being published to work around
this.

```bash
for PACKAGE in deb rpm; do
    ./gradlew --info \
        -PpackagePrefix="" \
        -PpackageType=$PACKAGE \
        -PpackageOrg=rundeckpro \
        -PpackageRevision=1 \
        bintrayUpload
done
```