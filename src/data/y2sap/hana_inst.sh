#!/bin/bash

# hana_inst.sh - is a script used to install SAP HANA
#
# Copyright (c) 2013 SAP AG
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
		# `basename $0` -i -m -s -n -p -t -y -h -g
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
ARCH=$( uname -m | tr [:lower:] [:upper:] )

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
TMPDIR=`mktemp -t -d sap_install_XXXXX`
chmod 755 $TMPDIR
MEDIA_TARGET=$( dirname $SAPCD_INSTMASTER)

if [ "${ARCH}" = "PPC64LE" ]; then
	if [ ! -d ${SAPCD_INSTMASTER}/DATA_UNITS/HDB_SERVER_LINUX_${ARCH} ]; then
 	 	ARCH="PPC64"
	fi
fi

# <n>th installation on this host. Specified by installation sub-directory. For multiple installations on a single host
INSTALL_COUNT=$( echo ${MEDIA_TARGET} | awk -F '/' '{print $NF}' )

# YaST Uebergabeparameterdateien
A_MASTERPASS="${MEDIA_TARGET}/ay_q_masterpass"
A_SID="${MEDIA_TARGET}/ay_q_sid"
A_SAPINSTNR="${MEDIA_TARGET}/ay_q_sapinstnr"
A_FILES="${A_SID} ${A_SAPINSTNR} ${A_MASTERPASS}"
A_SAPMDC=`< ${MEDIA_TARGET}/ay_q_sapmdc`

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
ERR_nomasterpass=14
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

do_exit() {
        exit_code=$1
        if [ ${exit_code} -le ${ERR_last} ]; then
                echo -e "${err_message[${exit_code}]}"
                yast_popup_wait "${err_message[${exit_code}]}"
        fi
        exit ${exit_code}
}


yast_popup () {

        if [ "$NOGUI" = "yes" ]; then
                echo $1
                return
        fi

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


yast_popup_timed () {

        if [ "$NOGUI" = "yes" ]; then
                echo $1
                return
        fi

	# open a YaST popup with the given text
	local tmpfile

        tmpfile="${TMPDIR}/yast_popup.ycp"

	cat > ${tmpfile} <<-EOF
		{
			import "Popup";
			Popup::ShowTextTimed ( "Information", "$1", 10 );
		}
EOF

	[ -x /sbin/yast2 ] && /sbin/yast2 ${tmpfile}
	rm ${tmpfile}
}


yast_popup_wait () {

        if [ "$NOGUI" = "yes" ]; then
                echo $1
                return
        fi

	# open a YaST popup with the given text and wait for user input
        # used for program termination message
	local tmpfile

	tmpfile="${TMPDIR}/yast_popup_wait.ycp"

	cat > ${tmpfile} <<-EOF
		{
			import "Popup";
			Popup::AnyMessage ( "Program Termination", "$1");
		}
EOF

	[ -x /sbin/yast2 ] && /sbin/yast2 ${tmpfile} 
	rm ${tmpfile}
}

hana_check_components()
{
   components_not_found=""
   for component in ${COMPONENTS}; do
       if [ ! -d ${MEDIA_TARGET}/Instmaster/DATA_UNITS/${component} ]; then
           found=0
           components_not_found="${components_not_found}\n${component}"
       fi
   done
   echo ${components_not_found}
}

hana_volumes()
{
   [ -f ${A_SID} ] && SID=`< ${A_SID}`
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
   [ -f ${A_SID} ] && SID=`< ${A_SID}`
   SID=${SID:="NDB"}

   # SAP Instance Number to use
   [ -f ${A_SAPINSTNR} ] && SAPINSTNR=`< ${A_SAPINSTNR}`
   SAPINSTNR=${SAPINSTNR:="00"}

   # Masterpassword for installation
   [ -f ${A_MASTERPASS} ] && MASTERPASS=`< ${A_MASTERPASS}`
   if [ -z "${MASTERPASS}" ]; then
       echo "Warning: MASTERPASS not set!"
   fi
}

hana_setenv_lcm()
{
  cat > ~/pwds.xml <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<Passwords>
   <password>${MASTERPASS}</password>
   <sapadm_password>${MASTERPASS}</sapadm_password>
   <system_user_password>${MASTERPASS}</system_user_password>
</Passwords>
EOF
}


hana_setenv_unified_installer()
{  
  # there are two versions of the HANA Unified Installer response file
  # Try the newer one if present
  oldfile=${MEDIA_TARGET}/Instmaster/DATA_UNITS/HANA_IM_LINUX__${ARCH}/setuphana.slmodel.template
  newfile=${oldfile}.v2
  if [ -f ${newfile} ]; then
    FILE=${newfile}

    oldstring="<dataPath></dataPath>"
    newstring="<dataPath>${hanadatadir}/${SID}</dataPath>"
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring="<logPath></logPath>"
    newstring="<logPath>${hanalogdir}/${SID}</logPath>"
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring="<sapmntPath>/hanamnt</sapmntPath>"
    newstring="<sapmntPath>/hana/shared</sapmntPath>"
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring="<instanceNumber></instanceNumber>"
    newstring="<instanceNumber>${SAPINSTNR}</instanceNumber>"
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring="<sid></sid>"
    newstring="<sid>${SID}</sid>"
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring="<hdbHost></hdbHost>"
    newstring="<hdbHost>`hostname -f`</hdbHost>"
    sed -i "s@${oldstring}@${newstring}@" ${FILE}
  else
    FILE=${oldfile}

    oldstring='${DATAPATH}'
    newstring=${hanadatadir}/${SID}
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring='${LOGPATH}'
    newstring=${hanalogdir}/${SID}
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring='/hanamnt'
    newstring='/hana/shared'
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring='${INSTANCENUMBER}'
    newstring=${SAPINSTNR}
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring='${SID}'
    newstring=${SID}
    sed -i "s@${oldstring}@${newstring}@" ${FILE}

    oldstring='${HDBHOST}'
    newstring=`hostname -f`
    sed -i "s@${oldstring}@${newstring}@" ${FILE}
  fi
}

cleanup() {
  # Cleanup
  rm -f  ${MEDIA_TARGET}/ay_*
  # the ^[ is a escape character "strg-v ESC" !! don't cut'n'paste it
  sed -i "s${MASTERPASS}**********g" /var/log/YaST2/y2log
  sed -i "s${MASTERPASS}**********g" /var/adm/autoinstall/logs/*

  rm -rf ${SAPCD_INSTMASTER}
  # delete since created via mktemp
  rm -rf ${TMPDIR}
}

hana_installation_summary ()
{
        # document the parameters used when installing for documentation and
        # open a YaST popup after the installation finished
        local tmpfile
        local summary_file

        summary_file="/root/installation${INSTALL_COUNT}_summary_${SID}.txt"
        tmpfile="${TMPDIR}/yast_popup_inst_summary.ycp"
        phys_ip=`host \`hostname\` | awk {'print $4'}`
	phys_ip=$( ip address show  | grep $phys_ip | gawk '{ print $2 }' )

        cat > ${summary_file} <<-EOF
        #########################################################################
        # The system ${SID} is installed with the following parameters
        # ( File can be found here: ${summary_file} )
        #########################################################################
        # Hostname:	`hostname`
        # Domain Name:	`dnsdomainname`
        # IP Address:	${phys_ip}
        # Domain Searchlist:	`grep ^search /etc/resolv.conf | sed 's/search //'`
        # IP for Nameserver:	`grep ^nameserver /etc/resolv.conf | sed 's/nameserver //' | tr '\n' ' '`
        # Default Gateway:	$( ip route list | gawk '/default/ { print $3}' )
        #
        # SAP HANA System ID:	${SID}
        # SAP HANA Instance:	${SAPINSTNR}
        # Data Volume:	${hanadatadir}
        # Log Volume:	${hanalogdir}
        #########################################################################
        # `basename $0` ended at `date +"%Y/%m/%d, %T (%Z)"`
        #########################################################################
EOF

	cp ${summary_file} ${MEDIA_TARGET}/installationSuccesfullyFinished.dat

        if [ "$NOGUI" = "yes" ]; then
                cat ${summary_file}
                return
        fi

        cat > ${tmpfile} <<-EOF
                {
                        import "Popup";

#                        Popup::ShowFile ("Installation Summary: SAP HANA", "${summary_file}");
#                        Popup::AnyTimedMessage ( "Installation Summary: SAP HANA", source, 10 );
                        string source = (string) SCR::Read(.target.string, "${summary_file}");
                        Popup::ShowTextTimed ("Installation Summary: SAP HANA", source, 100);

                }
EOF

        /sbin/yast2 ${tmpfile}
        rm ${tmpfile}
}

hana_lcm_workflow()
{
   WORKDIR=/var/tmp/
   rc=0
   hana_volumes
   hana_get_input
   hana_setenv_lcm

   # Does the HANA media have 
   # 1. a full SPx DVD folder strucure ?
   # 2. or a selected components folder structure ?
   # 3. or a selected components folder structure built specifically for B1 ?
   if [ -d ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_SERVER_LINUX_${ARCH} ]; then
       # HANA SPx DVD folder structure: check for required HANA components
       missing=$(hana_check_components)
       if [ "${ARCH}" = "X86_64" ];then
           COMPONENTS="HDB_CLIENT_LINUX_${ARCH} HDB_SERVER_LINUX_${ARCH} HDB_AFL_LINUX_${ARCH} HDB_STUDIO_LINUX_${ARCH} HDB_CLIENT_LINUXINTEL"
           LCM_COMPONENTS=client,afl,studio,server
       else
           if [ "${ARCH:0:5}" = "PPC64LE" ];then
              COMPONENTS="HDB_CLIENT_LINUX_${ARCH} HDB_SERVER_LINUX_${ARCH} HDB_AFL_LINUX_${ARCH}"
              LCM_COMPONENTS=client,afl,server
           else
              yast_popup_wait "Cannot install HANA. Platform ${ARCH} not supported by SUSE installation wizard."
              rc=1
           fi
       fi
       cd ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_SERVER_LINUX_${ARCH}
   else
       if [ -d ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP_HANA_DATABASE ]; then
           # check for required HANA components
           if [ "${ARCH}" = "X86_64" ];then
              COMPONENTS='SAP_HANA_AFL SAP_HANA_CLIENT SAP_HANA_CLIENT32 SAP_HANA_DATABASE SAP_HANA_STUDIO'
              LCM_COMPONENTS=client,afl,studio,server
           else
              if [ "${ARCH:0:5}" = "PPC64LE" ];then
                 COMPONENTS='SAP_HANA_AFL SAP_HANA_CLIENT SAP_HANA_DATABASE'
                 LCM_COMPONENTS=client,afl,server
              else
                 yast_popup_wait "Cannot install HANA. Platform ${ARCH} not supported by SUSE installation wizard."
                 rc=1
              fi
           fi
           missing=$(hana_check_components)
           LCM_COMPONENTS=client,afl,studio,server
           cd ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP_HANA_DATABASE
       else
           if [ -d ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP\ HANA\ DATABASE\ 1.0\ FOR\ B1 ]; then
              LCM_COMPONENTS=all
              LCM_COMPONENTS_ROOT="--component_root=${MEDIA_TARGET}/Instmaster/DATA_UNITS"
              cd ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP\ HANA\ DATABASE\ 1.0\ FOR\ B1/LINX64SUSE/SAP_HANA_DATABASE
           else
              missing='for full Service Pack: HDB_SERVER_LINUX_${ARCH}\nfor Revision Update: SAP_HANA_DATABASE'
           fi
       fi
   fi

   if [ ! -z "${missing}" ]; then
       yast_popup_wait "Cannot install HANA. The following folders are expected on the media:\n${missing}"
       rc=1
   else
      case $A_SAPMDC in
	no )
	  echo -e "db_mode=\n"  > ${MEDIA_TARGET}/hana_mdc.conf
	;;
	low )
	  echo -e "db_mode=multidb\ndb_isolation=low\n"  > ${MEDIA_TARGET}/hana_mdc.conf
	;;
	high )
	  echo -e "db_mode=multidb\ndb_isolation=high\n"  > ${MEDIA_TARGET}/hana_mdc.conf
	;;
      esac
      cat ~/pwds.xml | ./hdblcm --batch --action=install ${LCM_COMPONENTS_ROOT} --components=${LCM_COMPONENTS} --sid=${SID} --number=${SAPINSTNR} --read_password_from_stdin=xml --configfile=${MEDIA_TARGET}/hana_mdc.conf
      rc=$?
      rm  ~/pwds.xml
   fi
   return $rc
}

hana_unified_installer_workflow()
{
   WORKDIR=/var/tmp/hanainst
   DB_USER=SYSTEM
   rm -rf ${WORKDIR}
   mkdir -p ${WORKDIR}
   hana_volumes
   hana_get_input
   hana_setenv_unified_installer

   oldfile=${MEDIA_TARGET}/Instmaster/DATA_UNITS/HANA_IM_LINUX__${ARCH}/setuphana.slmodel.template
   newfile=${oldfile}.v2
   if [ -f ${newfile} ]; then
     FILE=${newfile}
   else
     FILE=${oldfile}
   fi

   LINUX26_SUPPORT=/usr/bin/uname26  # workaround for saposcol bug (does not detect Linux kernel 3.x which is shipped with SLES11 SP2)
   echo -e "`cat ${MEDIA_TARGET}/ay_q_masterpass`\n`cat ${MEDIA_TARGET}/ay_q_masterpass`" | ${LINUX26_SUPPORT} ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HANA_IM_LINUX__${ARCH}/setup.sh ${WORKDIR} ${FILE}
   # Unified Installer always returns rc 0, regardless of success :-(
   # workaround: test connection to HANA to determine success
   [ -f ${A_SID} ] && SID=`< ${A_SID}`
   SID=${SID:="NDB"}
   sid=`echo $SID | tr '[:upper:]' '[:lower:]'`
   su - ${sid}adm -c "hdbsql -i ${SAPINSTNR} -u ${DB_USER} -p ${MASTERPASS} -jC 'select * from sys.dummy'" > /dev/null >&2
   rc=$?

   # install AFL (required for B1)
   cd ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_AFL_LINUX_${ARCH}
   if [ $? -eq 0 ]; then
      ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HANA_IM_LINUX__${ARCH}/SAPCAR -xvf ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_AFL_LINUX_${ARCH}/IMDB_AFL100_*.SAR
      if [ $? -eq 0 ]; then
          cd SAP_HANA_AFL
          ./hdbinst -b -p `cat ${MEDIA_TARGET}/ay_q_masterpass` -s ${SID}
          rc=$?
          if [ $rc -ne 0 ]; then
             echo "could not install AFL, error=$rc"
          fi
      else
         echo "could not extract ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_AFL_LINUX_${ARCH}/IMDB_AFL100_*.SAR"
      fi
   else
      echo "AFL directory ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_AFL_LINUX_${ARCH} does not exist"
      rc=1
   fi
   
   return $rc
}

extract_media_archives()
{
   # try to extract all SAR archives on SAP media in the respective directories, if possible
   SAPCAR=`find ${MEDIA_TARGET}/Instmaster -name SAPCAR`
   if [ -n ${SAPCAR} ]; then
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
   # determine proper installation tool:
   # HANA 1.0 <= SP6: Unified Installer
   # HANA 1.0 => SP7: Life Cycle Manager (hdblcm)
   extract_media_archives
   HDBLCM=`find ${MEDIA_TARGET}/Instmaster/DATA_UNITS/ -name hdblcm`
   if [ -n "${HDBLCM}" ]; then
      hana_lcm_workflow
   else
      COMPONENTS="HANA_IM_LINUX__${ARCH} HDB_CLIENT_LINUX_${ARCH} HDB_SERVER_LINUX_${ARCH} SAP_HOST_AGENT_LINUX_X64 HDB_AFL_LINUX_${ARCH} HDB_STUDIO_LINUX_${ARCH} HDB_CLIENT_LINUXINTEL"
      missing=$(hana_check_components)
      if [ ! -z ${missing} ]; then
         yast_popup_wait "Cannot install, HANA component folders missing on media: ${missing}"
         rc=1
      else
         hana_unified_installer_workflow
         rc=$?
      fi
   fi

   if [ $rc -eq  0 ]; then
      # HDB 64-bit client: B1 expects client under /usr/sap.
      # Unified Installer does not allow to customize client path, so we set a link
      if [ ! -h /usr/sap/hdbclient ]; then
            ln -s /hana/shared/${SID}/hdbclient /usr/sap/hdbclient
      fi

      # HDB 32-bit client required for B1 Server/ServerTools
      if [ "${ARCH}" = "X86_64" ]; then 
         if [ -f ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_CLIENT_LINUXINTEL/hdbinst ]; then
            ${MEDIA_TARGET}/Instmaster/DATA_UNITS/HDB_CLIENT_LINUXINTEL/hdbinst --batch
         else
            if [ -f ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP_HANA_CLIENT32/SAP_HANA_CLIENT/hdbinst ]; then
               ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP_HANA_CLIENT32/SAP_HANA_CLIENT/hdbinst --batch
            else
               if [ -f ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP\ HANA\ CLIENT\ 1.0\ FOR\ B1/LINX32SUSE/SAP_HANA_CLIENT/hdbinst ]; then
                  ${MEDIA_TARGET}/Instmaster/DATA_UNITS/SAP\ HANA\ CLIENT\ 1.0\ FOR\ B1/LINX32SUSE/SAP_HANA_CLIENT/hdbinst --batch
               else
                  yast_popup_wait "Cannot find HANA 32-bit client, please install manually before SAP BusinessOne installation"
               fi
            fi
         fi
      fi
   fi

   if [ $rc -eq 0 ]; then
      # Cleanup-PopUp
      #yast_popup "Installation finished."
      
      hana_installation_summary
   else
      yast_popup_wait "Installation failed.\nFor details please check log files at /var/tmp and /var/adm/autoinstall/logs"
   fi

   cp ${MEDIA_TARGET}/ay_q_sid /dev/shm
   cp ${MEDIA_TARGET}/ay_q_sapinstnr /dev/shm
   #cp ${MEDIA_TARGET}/ay_q_masterpass /dev/shm
   cleanup

exit $rc
