#!/bin/bash

# trex_inst.sh - is a script used to install SAP TREX
#
# Copyright (c) 2016 SUSE Linux GmbH 
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
if [ -e $SAPINST_DIR/ay_q_virt_hostname ]; then
	VIRTHOSTNAME=$( cat $SAPINST_DIR/ay_q_virt_hostname )
else
	VIRTHOSTNAME=$( hostname -f )
fi

sid=$( echo $SID | tr [:upper:] [:lower:] )

# Functions
yast_popup () {
    # open a YaST popup with the given text
    local tmpfile
        tmpfile="${TMPDIR}/yast_popup.ycp"
    cat > ${tmpfile} <<-EOF
        {
            import "Popup";
            Popup::AnyTimedMessage ( "", "$1", 10 );
        }
EOF
    [ -x /sbin/yast2 ] && /sbin/yast2 ${tmpfile}
    rm ${tmpfile}
}


# Check if /sapmnt exists or create it

if [ ! -d "/sapmnt" ]; then
    mkdir /sapmnt
fi

# Run installation
$SAPCD_INSTMASTER/install.sh \
        --action=install \
        --logdir=/tmp/sapinst_log_${SID} \
        --sid=$SID \
        --instance=$INST \
        --target=/sapmnt \
        --host=$VIRTHOSTNAME \
        --sidadmid= \
        --sapsysid=79 \
        --usershell=/bin/bash \
        --userhome=/home/${sid}adm \
        --password=$MASTERPW

# Provide return code
INST_RETURN_VALUE=$?

# Ignore return code if installationSuccesfullyFinished.dat can be found
if [ 0 -ne ${INST_RETURN_VALUE} ]; then
         # SAPINST crashed?
        yast_popup "The SAP installation seems to have crashed...\nCheck the log files in '/tmp/sapinst_log_${SID}'"
	rm ${SAPINST_DIR}/ay_*
else
	# Cleanup-PopUp
	mv /tmp/sapinst_log_${SID}/installationSuccesfullyFinished.dat ${SAPINST_DIR}/installationSuccesfullyFinished.dat
	yast_popup "SAPINST finished.\nCleaning up and starting SAP system."
	rm ${SAPINST_DIR}/ay_*
	rm -rf ${$SAPCD_INSTMASTER}
	rm -rf /tmp/sapinst_log_${SID}
fi
