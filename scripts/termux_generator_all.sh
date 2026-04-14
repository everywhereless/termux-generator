build_all_packages() {
    set +e

    local bootstrap_architecture="$1"

    TERMUX_SCRIPTDIR="$(pwd)"

    DOCKERSCRIPT="$TERMUX_SCRIPTDIR/scripts/run-docker.sh"

    # a safe place outside of docker is just needed to temporarily store the results of the tests,
    # and I preferred not to use anywhere in $HOME.
    BUILDSTATUS_DIR="$TERMUX_SCRIPTDIR/build-validation-results"
    rm -rf "$BUILDSTATUS_DIR"
    mkdir -p "$BUILDSTATUS_DIR"

    PACKAGES=()

    for PKG in $(find "$TERMUX_SCRIPTDIR"/{packages,root-packages,x11-packages} \
        -mindepth 1 -maxdepth 1 -exec basename {} \;); do
        PACKAGES+=("$PKG")
    done

    echo "==============="
    echo "Build Order:"
    echo "==============="
    for PKG in "${PACKAGES[@]}"; do
        echo "$PKG"
    done
    echo "==============="

    # $TIER indicates what degree of "bootstrappability" is being tested currently.
    # higher values are considered as more difficult to build, or less likely to build successfully,
    # so if a package passes a higher tier, it is considered that it most likely (with possible exceptions)
    # would also pass all lower tiers if its build were tested at them too.

    # TIER=4 - builds in a docker container that has already built all other packages that it is possible to build without the container being deleted
    # TIER=3 - builds in a docker container that has been building many packages previously, but has not yet built all packages previously
    # TIER=2 - builds in a clean docker container without the -I argument to build-package.sh
    # TIER=1 - builds in a clean docker container with the -I argument to build-package.sh
    for PKG in "${PACKAGES[@]}"; do
        BUILDSTATUS_FILE="$BUILDSTATUS_DIR/$PKG"
        BUILDLOG_FILE="$BUILDSTATUS_DIR/$PKG.log"

        TIER=3
        export CONTAINER_NAME="termux-generator-package-builder"

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"

        if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
            echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
            continue
        fi

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"

        TIER=2
        export CONTAINER_NAME="tier-$TIER-termux-generator-package-builder"
        docker container kill $CONTAINER_NAME
        docker container rm $CONTAINER_NAME
        # Replace symbolic link /system which is inside the termux-package-builder docker image
        # pointed to /data/data/com.termux/aosp by default
        # https://github.com/termux/termux-packages/blob/650907de80114cc53b20b181161f993e3ad0dfad/scripts/setup-ubuntu.sh#L371
        # needed for building pypy and similar packages
        "$DOCKERSCRIPT" sudo ln -sf "/data/data/$TERMUX_APP__PACKAGE_NAME/aosp" /system

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"

        if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
            echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
            continue
        fi

        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
        echo "===============" | tee -a "$BUILDLOG_FILE"
        echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"

        # TIER=1
        # export CONTAINER_NAME="tier-$TIER-termux-package-builder"
        # docker kill $CONTAINER_NAME
        # docker rm $CONTAINER_NAME

        # echo "===============" | tee -a "$BUILDLOG_FILE"
        # echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
        # echo "===============" | tee -a "$BUILDLOG_FILE"

        # if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" -I "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
        #     echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
        #     continue
        # fi

        # echo "===============" | tee -a "$BUILDLOG_FILE"
        # echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
        # echo "===============" | tee -a "$BUILDLOG_FILE"
        # echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"
    done

    # TIER=4
    # export CONTAINER_NAME="tier-3-termux-package-builder"

    # for PKG in "${PACKAGES[@]}"; do
    #     BUILDSTATUS_FILE="$BUILDSTATUS_DIR/$PKG"
    #     BUILDLOG_FILE="$BUILDSTATUS_DIR/$PKG.log"

    #     echo "===============" | tee -a "$BUILDLOG_FILE"
    #     echo "Building $PKG at tier $TIER..." | tee -a "$BUILDLOG_FILE"
    #     echo "===============" | tee -a "$BUILDLOG_FILE"

    #     if "$DOCKERSCRIPT" ./build-package.sh -a "$bootstrap_architecture" -f "$PKG" 2>&1 | tee -a "$BUILDLOG_FILE"; then
    #         echo "passed tier $TIER" >> "$BUILDSTATUS_FILE"
    #         continue
    #     fi

    #     echo "===============" | tee -a "$BUILDLOG_FILE"
    #     echo "$PKG failed to build at tier $TIER!" | tee -a "$BUILDLOG_FILE"
    #     echo "===============" | tee -a "$BUILDLOG_FILE"
    #     echo "failed tier $TIER" >> "$BUILDSTATUS_FILE"
    # done

    set -e
}
