#!/bin/sh

find . -name '*.kdev4' -delete

VERSION=`cat VERSION`
rsync -aV src/ sap-installation-wizard-$VERSION/
cp inifiles/*  sap-installation-wizard-$VERSION/includes/
asks/create_products_xml.sh sap-installation-wizard-$VERSION

tar chfvj "sap-installation-wizard-${VERSION}.tar.bz2" sap-installation-wizard-$VERSION

rm -rf sap-installation-wizard-$VERSION

