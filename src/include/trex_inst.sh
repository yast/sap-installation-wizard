#!/bin/bash

# sap_inst.sh - is a script used to install SAP products
#
# Copyright (c) 2016 SUSE G,bH 
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation only version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License 
# for more details.
#
# You should have received a copy of the GNU General Public License 
# along with this program; if not, see <http://www.gnu.org/licenses/>.

usage () {
        cat <<-EOF

                #######################################################################
                # `basename $0` -i -m [ -d -t -g ]
                #
                #  i ) SAPINST_PRODUCT_ID - SAPINST Product ID
                #  m ) SAPCD_INSTMASTER - Path to the SAP Installation Master Medium
                #  d ) SAPINST_DIR - The directory where the installation will be prepared
                #  t ) DBTYPE - Database type, e.g. ADA, DB6, ORA or SYB
                #  g ) INSTALLATION_TYPE - Start SAPINST in GUI-mode? 
                #  y ) PRODUCT_TYPE - Product Type, eg. SAPINST, HANA, B1
                #      (default: GUI, anything else starts SAPINST in dark mode)
                #
                #######################################################################
EOF
        echo
}

SAPCD_INSTMASTER=""
SAPINST_PRODUCT_ID=""
SAPINSTNR=""
SAPINST_DIR=""

# Optionally overrule parameters from answer files by command line arguments
while getopts "i:m:d:t:g:y:h\?" options; do
        case $options in
                i ) SAPINST_PRODUCT_ID=$OPTARG;;  # SAPINST Product ID
                m ) SAPCD_INSTMASTER=${OPTARG};; # Path to the SAP Installation Master Medium (has to be full-qualified)
                d ) SAPINST_DIR=${OPTARG};; # The directory where the installation will be prepared
                t ) DBTYPE=${OPTARG};; # Database type, e.g. ADA, DB6, ORA, SYB or HDB
                g ) INSTALLATION_TYPE=${OPTARG};; # Start SAPINST in GUI-mode? (default: GUI, anything else starts non-graphical)
                y ) PRODUCT_TYPE=${OPTARG};; # Product Type, eg. HANA, B1
                h | \? ) usage
                        exit $ERR_invalid_args;;
                * ) usage
                        exit $ERR_invalid_args;;
        esac
done

MASTERPW=$( cat $SAPINST_DIR/ay_q_masterPwd )
SID=$( cat $SAPINST_DIR/ay_q_sid )
INST=$( cat $SAPINST_DIR/ay_q_instanceNumber )
