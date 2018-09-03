Rundeck DEB/RPM Packaging
=========================

Consolidated deb and rpm packaging and signing.

## Usage

### Package
```
./gradlew \
            -PpackageRelease=$RELEASE_NUM \
            clean packageArtifacts
```

**Inputs:**  
`artifacts/*.war`

**Outputs:**  
`build/distributions/*.{deb,rpm}`

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