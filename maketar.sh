#!/bin/sh

VERSION=`cat VERSION`
if [ ! -e sap-installation-wizard-$VERSION ]; then
    ln -s src sap-installation-wizard-$VERSION
fi
tar chfvj "sap-installation-wizard-${VERSION}.tar.bz2" sap-installation-wizard-$VERSION
