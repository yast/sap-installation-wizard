#!/bin/bash -x

# hana_inst.sh - is a script used to install SAP HANA
#
# Copyright (c) 2013 SAP AG
# Copyright (c) [2013-2022] SUSE LLC
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
    # $(basename $0) -i -m -s -n -p -t -y -h -g
    #
    #  i ) SAPINST_PRODUCT_ID - SAPINST Product ID
    #  m ) SAPCD_INSTMASTER - Path to the SAP Installation Master Medium
    #  d ) SAPINST_DIR - The directory where the installation will be prepared
    #  s ) SID - SAP System ID
    #  n ) SAPINSTNR - SAP Instance Number (two digits)
    #  p ) MASTERPASS - SAP Masterpassword to use
    #  t ) DBTYPE - Database type, e.g. ADA, DB6, ORA or SYB
    #  y ) PRODUCT_TYPE - Product Type, eg. SAPINST, HANA, B1
    #  g ) Do not use gui. All message should be put into STDOUT
    #
    #######################################################################
EOF
  echo
}

SAPCD_INSTMASTER=""
SAPINST_PRODUCT_ID=""
ARCH=$(uname -m | tr [:lower:] [:upper:])

# Optionally overrule parameters from answer files by command line arguments
while getopts "i:m:d:s:n:p:t:y:hg\?" options; do
  case $options in
    i ) SAPINST_PRODUCT_ID=$OPTARG;;  # SAPINST Product ID
    m ) SAPCD_INSTMASTER=${OPTARG};; # Path to the SAP Installation Master Medium (has to be full-qualified)
    d ) SAPINST_DIR=${OPTARG};; # The directory where the installation will be prepared
    s ) SID=$OPTARG;;  # SAP System ID
    n ) SAPINSTNR=$OPTARG;;  # SAP Instance Number
    p ) MASTERPASS=$OPTARG;;  # Masterpassword
    t ) DBTYPE=${OPTARG};; # Database type, e.g. ADA, DB6, ORA, SYB or HDB
    y ) PRODUCT_TYPE=${OPTARG};; # Product Type, eg. HANA, B1
    g ) NOGUI="yes";;
    h | \? ) usage
            exit $ERR_invalid_args;;
    * ) usage
            exit $ERR_invalid_args;;
  esac
done

###########################################
# globals
###########################################
# TMPDIR="/tmp"
TMPDIR=$(mktemp -t -d sap_install_XXXXX)
chmod 755 $TMPDIR
MEDIA_TARGET=$(dirname $SAPCD_INSTMASTER)

if [ "${ARCH}" = "PPC64LE" ]; then
  if [ ! -d ${SAPCD_INSTMASTER}/DATA_UNITS/HDB_SERVER_LINUX_${ARCH} ]; then
    ARCH="PPC64"
  fi
fi

# <n>th installation on this host. Specified by installation sub-directory. For multiple installations on a single host
INSTALL_COUNT=$(echo ${MEDIA_TARGET} | awk -F '/' '{print $NF}')

# YaST Uebergabeparameterdateien
A_MASTERPASS="${MEDIA_TARGET}/ay_q_masterPwd"
A_SID="${MEDIA_TARGET}/ay_q_sid"
A_SAPINSTNR="${MEDIA_TARGET}/ay_q_sapinstnr"
A_FILES="${A_SID} ${A_SAPINSTNR} ${A_MASTERPASS}"
if [ -e ${MEDIA_TARGET}/ay_q_sapmdc ]; then
  A_SAPMDC=$(cat ${MEDIA_TARGET}/ay_q_sapmdc)
fi

###########################################
# Define ERRORS section
###########################################
ERR_invalid_args=1
ERR_no_suid=2
ERR_no_tars_found=3
ERR_unknown_vendor=4
ERR_no_ip_free=5
ERR_no_java_found=6
ERR_no_unrar_found=7
ERR_sap_no_eula=8
ERR_sap_eula_refused=9
ERR_create_xuser_failed=10
ERR_rpm_install=11
ERR_internal=12
ERR_missing_entries=13
ERR_nomasterPwd=14
ERR_last=15

err_message[0]="Ok"
err_message[1]="Invalid Arguments."
err_message[2]="You should be root to start this program."
err_message[3]="No SAP archives found."
err_message[4]="This installation supports only ${supported_string}"
err_message[5]="No free IP Address found using the following list : ${virt_ip_pool}"
err_message[6]="No Java Runtime found."
err_message[7]="No unrar found."
err_message[8]="No SAPEULA License found."
err_message[9]="License terms refused."
err_message[10]="Creation of .XUSER.62 failed."
err_message[11]="RPM Error."
err_message[12]="Internal error! Call stack: ${FUNC_NAME[@]}"
err_message[13]="Mandatory User input missing!"
err_message[14]="No Masterpassword provided"
err_message[15]=""

###########################################
# Functions:
###########################################

hana_check_components()
{
   components_not_found=""
   for component in ${COMPONENTS}; do
       if [ ! -d ${SAPCD_INSTMASTER}/DATA_UNITS/${component} ]; then
           found=0
           components_not_found="${components_not_found}\n${component}"
       fi
   done
   echo ${components_not_found}
}

hana_volumes()
{
   [ -f ${A_SID} ] && SID=$(cat ${A_SID})
   SID=${SID:="NDB"}
   hanamount=/hana/shared
   hanadatadir=/hana/data
   hanalogdir=/hana/log

   if [ ! -d ${hanamount} ]; then mkdir -p ${hanamount}; fi
   if [ ! -d ${hanadatadir}/${SID} ]; then mkdir -p ${hanadatadir}/${SID}; fi
   if [ ! -d ${hanalogdir}/${SID} ]; then mkdir -p ${hanalogdir}/${SID}; fi
}

hana_get_input()
{
   # SAP System ID
   [ -f ${A_SID} ] && SID=$(cat ${A_SID})
   SID=${SID:="NDB"}

   # SAP Instance Number to use
   [ -f ${A_SAPINSTNR} ] && SAPINSTNR=$(cat ${A_SAPINSTNR})
   SAPINSTNR=${SAPINSTNR:="00"}

   # Masterpassword for installation
   [ -f ${A_MASTERPASS} ] && MASTERPASS=$(cat ${A_MASTERPASS})
   if [ -z "${MASTERPASS}" ]; then
       echo "Warning: MASTERPASS not set!"
   fi
}

hana_setenv_lcm()
{
  cat > ~/pwds.xml <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<Passwords>
    <root_password><![CDATA[${MASTERPASS}]]></root_password>
    <sapadm_password><![CDATA[${MASTERPASS}]]></sapadm_password>
    <master_password><![CDATA[${MASTERPASS}]]></master_password>
    <sapadm_password><![CDATA[${MASTERPASS}]]></sapadm_password>
    <password><![CDATA[${MASTERPASS}]]></password>
    <system_user_password><![CDATA[${MASTERPASS}]]></system_user_password>
    <lss_user_password><![CDATA[${MASTERPASS}]]></lss_user_password>
    <lss_backup_password><![CDATA[${MASTERPASS}]]></lss_backup_password>
    <streaming_cluster_manager_password><![CDATA[${MASTERPASS}]]></streaming_cluster_manager_password>
    <ase_user_password><![CDATA[${MASTERPASS}]]></ase_user_password>
    <org_manager_password><![CDATA[${MASTERPASS}]]></org_manager_password>
</Passwords>
EOF
}

cleanup() {
  if [ ! -e /root/hana-install-do-not-rm ]; then
    # Cleanup
    rm -f  ${MEDIA_TARGET}/ay_*
    rm -rf ${SAPCD_INSTMASTER}
    rm -rf ${TMPDIR}
  fi
}

hana_installation_summary ()
{
  # document the parameters used when installing for documentation and
  # open a YaST popup after the installation finished
  local tmpfile
  local summary_file

  summary_file="/root/installation${INSTALL_COUNT}_summary_${SID}.txt"
  phys_ip=$(host $(hostname) | awk {'print $4'})
  phys_ip=$(ip address show  | grep $phys_ip | gawk '{ print $2 }')
  nameserver=$(grep ^nameserver /etc/resolv.conf | sed 's/nameserver //' | tr '\n' ' ')

  cat > ${summary_file} <<-EOF
  #########################################################################
  # The system ${SID} is installed with the following parameters
  # ( File can be found here: ${summary_file} )
  #########################################################################
  # Hostname:  $(hostname)
  # Domain Name:  $(dnsdomainname)
  # IP Address:  ${phys_ip}
  # Domain Searchlist:  $(grep ^search /etc/resolv.conf | sed 's/search //')
  # IP for Nameserver:  ${nameserver}
  # Default Gateway:     $(ip route list | gawk '/default/ { print $3}')
  #
  # SAP HANA System ID:  ${SID}
  # SAP HANA Instance:  ${SAPINSTNR}
  # Data Volume:  ${hanadatadir}
  # Log Volume:  ${hanalogdir}
  #########################################################################
  # $(basename $0) ended at $(date +"%Y/%m/%d, %T (%Z)")
  #########################################################################
EOF

  cp  ${summary_file} ${MEDIA_TARGET}/installationSuccesfullyFinished.dat
  cp  ${summary_file} /var/run/sap-wizard/installationSuccesfullyFinished.dat
  cat ${summary_file}

}

hana_lcm_workflow()
{
   WORKDIR=/var/tmp/
   rc=0
   hana_volumes
   hana_get_input
   hana_setenv_lcm

   # Detect if it is a B1 installation
   B1=$(find ${SAPCD_INSTMASTER} -maxdepth 1 -type f -exec grep FOR.B1 {} \;)
   if [ -n "$B1" -a ! -d ${SAPCD_INSTMASTER}/SAP_HANA_DATABASE ]; then
     # Move the component directories into the first level
     find ${SAPCD_INSTMASTER}/DATA_UNITS/  -type d -name "SAP_HANA_*" -exec mv {} ${SAPCD_INSTMASTER}/ \;
   fi
   # Find the installer
   HDBLCM=$(find ${SAPCD_INSTMASTER} -name hdblcm | grep -m 1 -P 'DATABASE|SERVER')
   HDBLCMDIR=$(dirname "${HDBLCM}")
   if [ -z "${HDBLCM}" ]; then
     echo "Cannot find hdblcm" > ${MEDIA_TARGET}/installation_failed
     rc=1
     return $rc
   fi
   case $A_SAPMDC in
     no)
       echo -e "db_mode=\n"  > ${MEDIA_TARGET}/hana_mdc.conf
     ;;
     low)
       echo -e "db_mode=multidb\ndb_isolation=low\n"  > ${MEDIA_TARGET}/hana_mdc.conf
     ;;
     high)
       echo -e "db_mode=multidb\ndb_isolation=high\n"  > ${MEDIA_TARGET}/hana_mdc.conf
     ;;
   esac
   cd "${HDBLCMDIR}"
   TOIGNORE="check_signature_file"
   if [ -e /root/hana-install-ignore ]; then
     TOIGNORE=$(cat /root/hana-install-ignore)
   fi
   if [ -e ${MEDIA_TARGET}/hana_mdc.conf ]; then
       cat ~/pwds.xml | ./hdblcm --batch --action=install \
            --ignore=$TOIGNORE \
            --lss_trust_unsigned_server \
            --components=all \
            --sid=${SID} \
            --number=${SAPINSTNR} \
            --groupid=79 \
            --read_password_from_stdin=xml \
            --configfile=${MEDIA_TARGET}/hana_mdc.conf
   else
       cat ~/pwds.xml | ./hdblcm --batch --action=install \
            --ignore=$TOIGNORE \
            --lss_trust_unsigned_server \
            --components=all \
            --sid=${SID} \
            --number=${SAPINSTNR} \
            --groupid=79 \
            --read_password_from_stdin=xml
   fi
   rc=$?
   rm  ~/pwds.xml
   return $rc
}


extract_media_archives()
{
   # try to extract all SAR archives on SAP media in the respective directories, if possible
   SAPCAR=$(find ${MEDIA_TARGET}/Instmaster -name SAPCAR)
   if [ -n "${SAPCAR}" ]; then
      if [ ! -x ${SAPCAR} ]; then
         chmod +x ${SAPCAR}
      fi
      find ${MEDIA_TARGET}/Instmaster -name "*.SAR" -type f -execdir ${SAPCAR} -manifest SIGNATURE.SMF -xf '{}' +
   fi
}

###########################################
# Main
###########################################

rc=0
missing=''
extract_media_archives
hana_lcm_workflow
if [ $rc -eq 0 ]; then
   hana_installation_summary
fi

cleanup

exit $rc
