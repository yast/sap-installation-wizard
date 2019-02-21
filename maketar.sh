#!/bin/sh -x

find . -name '*.kdev4' -delete

VERSION=`cat VERSION`
rsync -av src/ sap-installation-wizard-$VERSION/
cp inifiles/*  sap-installation-wizard-$VERSION/data/y2sap/
cd asks
./create_products_xml.sh sap-installation-wizard-$VERSION
cd ..

tar chfj "sap-installation-wizard-${VERSION}.tar.bz2" sap-installation-wizard-$VERSION

rm -rf sap-installation-wizard-$VERSION

