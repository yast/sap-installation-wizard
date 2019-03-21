#!/bin/sh -x

cp inifiles/*  src/data/y2sap/
cd asks
./create_products_xml.sh sap-installation-wizard-$VERSION
cd ..
