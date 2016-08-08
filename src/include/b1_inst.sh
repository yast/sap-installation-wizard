#!/bin/bash

# b1_inst.sh - is a script used to install SAP Business One products:
#   SAP Business One, version for SAP HANA
#   SAP Business One analytics powered by SAP HANA
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
		# `basename $0` -i -m [-s | -n | -p | -k | -d | -l | -g ]
		#
		#  i ) SAPINST_PRODUCT_ID - SAPINST Product ID
		#  m ) SAPCD_INSTMASTER - Path to the SAP Installation Master Medium
		#  d ) SAPINST_DIR - The directory where the installation will be prepared
		#  s ) SID - SAP System ID
		#  n ) SAPINSTNR - SAP Instance Number (two digits)
		#  p ) MASTERPASS - SAP Masterpassword to use
		#  t ) DBTYPE - Database type, e.g. ADA, DB6, ORA or SYB
		#  y ) PRODUCT_TYPE - Product Type, eg. SAPINST, HANA, B1
		#
		#######################################################################
EOF
	echo
}

SAPCD_INSTMASTER=""
SAPINST_PRODUCT_ID=""

# Optionally overrule parameters from answer files by command line arguments
while getopts "i:m:s:n:p:k:d:l:g:t:y:h\?" options; do
	case $options in
		i ) SAPINST_PRODUCT_ID=$OPTARG;;  # SAPINST Product ID
		m ) SAPCD_INSTMASTER=${OPTARG};; # Path to the SAP Installation Master Medium (has to be full-qualified)
		d ) SAPINST_DIR=${OPTARG};; # The directory where the installation will be prepared
		s ) SID=$OPTARG;;  # SAP System ID
		n ) SAPINSTNR=$OPTARG;;  # SAP Instance Number
		p ) MASTERPASS=$OPTARG;;  # Masterpassword
		t ) DBTYPE=${OPTARG};; # Database type, e.g. ADA, DB6, ORA, SYB or HDB
		y ) PRODUCT_TYPE=${OPTARG};; # Product Type, eg. HANA, B1
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

# <n>th installation on this host. Specified by installation sub-directory. For multiple installations on a single host
INSTALL_COUNT=$( echo ${MEDIA_TARGET} | awk -F '/' '{print $NF}' )

# YaST Uebergabeparameterdateien
A_IP_ADDR="${TMPDIR}/may_q_ip_addr"
A_MASTERPASS="${MEDIA_TARGET}/ay_q_masterpass"
A_SID="${MEDIA_TARGET}/ay_q_sid"
A_SAPINSTNR="${MEDIA_TARGET}/ay_q_sapinstnr"
A_FILES="${A_SID} ${A_SAPINSTNR} ${A_MASTERPASS}"

###########################################
# Define ERRORS section
###########################################
ERR_invalid_args=1

err_message[0]="Ok"
err_message[15]=""

###########################################
# Functions:
###########################################


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


yast_popup_timed () {
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

cleanup() {
  # Cleanup
  # SAPINST automatically creates the directory /tmp/sapinst_exe.*
  rm -rf /tmp/sapinst_exe.*
  rm -f  ${MEDIA_TARGET}/ay_*
  rm -rf ${SAPINST_WORK_DIR}
  # the ^[ is a escape character "strg-v ESC" !! don't cut'n'paste it
  sed -i "s${MASTERPASS}**********g" /var/log/YaST2/y2log
  sed -i "s${MASTERPASS}**********g" /var/adm/autoinstall/logs/*

  rm -rf ${MEDIA_TARGET}
  # delete since created via mktemp
  rm -rf ${TMPDIR}

# check if we stopped nscd during our installation
[ "${NSCD_RUNNING}" = "true" ] && service nscd start > /dev/null 2>&1
}


b1_installation_summary () {
        # document the parameters used when installing for documentation and
        # open a YaST popup after the installation finished
        local tmpfile
        local summary_file

        summary_file="/root/installation${INSTALL_COUNT}_summary_${SID}.txt"
        tmpfile="${TMPDIR}/yast_popup_inst_summary.ycp"
        phys_ip=`host \`hostname\` | awk {'print $4'}`
        phys_netmask=`ifconfig |grep ${phys_ip} | sed 's/.*://'`

        cat > ${summary_file} <<-EOF
        #########################################################################
        # The system ${SID} is installed with the following parameters
        # ( File can be found here: ${summary_file} )
        #########################################################################
        # Hostname:	`hostname`
        # Domain Name:	`dnsdomainname`
        # IP Address:	${phys_ip}
        # Netmask:	${phys_netmask}
        # Domain Searchlist:	`grep ^search /etc/resolv.conf | sed 's/search //'`
        # IP for Nameserver:	`grep ^nameserver /etc/resolv.conf | sed 's/nameserver //' | tr '\n' ' '`
        # Default Gateway:	`route -n | awk '{ if ( match($0,"^0.0.0.0" )) print $2 }'`
        #
        # SAP HANA System ID:	${SID}
        # SAP HANA Instance:	${SAPINSTNR}
        # Installation location: ${USER_INSTALL_DIR}
        #########################################################################
        # `basename $0` ended at `date +"%Y/%m/%d, %T (%Z)"`
        #########################################################################
EOF

        cat > ${tmpfile} <<-EOF
                {
                        string headline="Installation Summary: ${B1_PRODUCT}";
                        import "Popup";

#                        Popup::ShowFile ("Installation Summary: SAP Business One", "${summary_file}");
#                        Popup::AnyTimedMessage ( "Installation Summary: SAP Business One", source, 10 );
                        string source = (string) SCR::Read(.target.string, "${summary_file}");
                        Popup::ShowTextTimed (headline, source, 100);

                }
EOF

        /sbin/yast2 ${tmpfile}
        rm ${tmpfile}
}


b1h_install_parameters()
{
   tmpfile=/tmp/tmpfile.ycp
   cat > ${tmpfile} <<-EOF
   {
       import "UI";
       import "Wizard";

       any ret = nil;
       term parameterTable = \`Table(\`opt(\`keepSorting));
       parameterTable = add(parameterTable, \`header("Install parameter", "Default Value"));
       list parameterList = [];
       parameterList = add( parameterList, \`item("Installation folder", "${USER_INSTALL_DIR}"));
       parameterList = add( parameterList, \`item("Service Port", "40000"));
       parameterList = add( parameterList, \`item("Site User ID", "B1SiteUser"));
#       parameterList = add( parameterList, \`item("Site User Password", "master password"));
       parameterList = add( parameterList, \`item("SLD Certificate", "Self-signed"));
#       parameterList = add( parameterList, \`item("HANA DB Server name or IP", "`hostname`"));
#       parameterList = add( parameterList, \`item("HANA DB Server Port", "3${SAPINSTNR}15"));
       parameterList = add( parameterList, \`item("HANA DB User ID", "${DB_USER}"));
       parameterList = add( parameterList, \`item("Database Name", "SLDData"));
       parameterList = add( parameterList, \`item("Windows Domain User Authentication", "Skip"));
#       parameterList = add( parameterList, \`item("Set AutoStart for SAMBA service", "Yes"));
#       parameterList = add( parameterList, \`item("Landscape Server Address", "127.0.0.1"));
#       parameterList = add( parameterList, \`item("Landscape Server Port", "40000"));
#       parameterList = add( parameterList, \`item("Landscape Server Protocol", "https"));
#       parameterList = add( parameterList, \`item("Landscape Server Type", "OnPremise"));
#       parameterList = add( parameterList, \`item("XAPPs Certificate", "Self-signed"));
       parameterList = add( parameterList, \`item("Features selected for installation", "System Landscape Directory"));
       parameterList = add( parameterList, \`item("", "Server Tools: License Manager"));
       parameterList = add( parameterList, \`item("", "Server Tools: Mailer"));
       parameterList = add( parameterList, \`item("", "Server Tools: Extreme App Framework"));
       parameterList = add( parameterList, \`item("", "BusinessOne Server: System Components"));
       parameterList = add( parameterList, \`item("", "BusinessOne Server: System Database"));
       parameterList = add( parameterList, \`item("", "BusinessOne Server: Demo Database US"));
       parameterList = add( parameterList, \`item("", "BusinessOne Server: Help EN"));
       parameterList = add( parameterList, \`item("", "BusinessOne Server: Addons"));
       parameterList = add( parameterList, \`item("", "BusinessOne Server: MS Outlook Integration"));
       parameterList = add( parameterList, \`item("", "Analytics Features: SAP HANA Models"));
       parameterList = add( parameterList, \`item("", "Analytics Features: Tomcat Search"));
       parameterList = add( parameterList, \`item("", "Analytics Features: Tomcat Dashboard"));
       parameterList = add( parameterList, \`item("", "Analytics Features: Tomcat Data Staging"));
       parameterList = add( parameterList, \`item("", "Analytics Features: Tomcat Admin Console"));
       parameterList = add( parameterList, \`item("Apache Load Balancer", "Enabled (only v9.1 and higher)"));
       parameterList = add( parameterList, \`item("Apache Load Balancer Members", "3"));
       parameterList = add( parameterList, \`item("Apache Load Balancer max. Threads per Member", "30"));
       parameterList = add( parameterList, \`item("Apache Load Balancer Port", "50000"));
       parameterList = add( parameterList, \`item("Apache Load Balancer Member Ports", "50001,50002,50003"));

       parameterTable = add( parameterTable, parameterList);
       string helptext = "<p>Choose <b>Yes</b> if you want to install with the listed <b>default parameters</b>.<br>" +
                         "The installation will run silently without further dialogs.</p>" +
                         "<p>Choose <b>No</b> if you want to <b>customize the parameters</b> " +
                         "with the BusinessOne Install Wizard.</p>";
       UI::OpenDialog(\`VBox(
                         \`HBox(
                             \`HWeight(30, \`RichText(helptext)),
                             \`HWeight(70,
                                 \`VBox(
                                     \`Heading("SAP Business One Server Components:\nInstallation with Default Settings ?"),
                                     \`MinSize(61, 25, parameterTable),
                                     \`HBox(
                                         \`PushButton( \`id( \`yes ), "&Yes" ),
                                         \`PushButton( \`id( \`no  ), "&No"  )
                                      )
                                   )
                                )
                            )
                        )
                    );
       ret = UI::UserInput();
       UI::CloseDialog();
       if (ret == \`yes)
          return -16;
       else if (ret == \`no)
          return -15;
   }
EOF
}


b1h_install_properties()
{
   cat > "${FULLINSTPATH}/install.properties" <<-EOF
#B1 service group
B1_SERVICE_GROUP=b1service0
#B1 service user
B1_SERVICE_USER=b1service0
#Set AutoStart for SAMBA service?
B1S_SAMBA_AUTOSTART=true
#Overwrite the existing B1 Shared folder?
B1S_SHARED_FOLDER_OVERWRITE=true
#HANA DB Server name or IP
HANA_DATABASE_SERVER=localhost
#HANA_DATABASE_SERVER=`hostname`
#HANA DB Server Port
HANA_DATABASE_SERVER_PORT=3${SAPINSTNR}15
#HANA DB User ID
HANA_DATABASE_USER_ID=${DB_USER}
#HANA DB Password
HANA_DATABASE_USER_PASSWORD=${MASTERPASS}
#SLD Database Name
HANA_SLD_DATABASE_NAME=SLDData
#Installation folder
INSTALLATION_FOLDER=${USER_INSTALL_DIR}
#Correct Permissions on installation folder
INST_FOLDER_CORRECT_PERMISSIONS=false
#Service Port
SERVICE_PORT=40000
#Site User ID
SITE_USER_ID=B1SiteUser
#Site User Password
SITE_USER_PASSWORD=${MASTERPASS}
#SLD Certificate Action
SLD_CERTIFICATE_ACTION=self
#Path to SLD Certificate file
SLD_CERTIFICATE_FILE_PATH=${USER_INSTALL_DIR}/Common/tomcat/cert/https.p12
#Password to SLD Certificate file
SLD_CERTIFICATE_PASSWORD=${MASTERPASS}
#Landscape Server Address
SLD_SERVER_ADDR=127.0.0.1
#Landscape Server Port
SLD_SERVER_PORT=40000
#Landscape Server Protocol
SLD_SERVER_PROTOCOL=https
#Landscape Server Type Ondemand/OnPremise
SLD_SERVER_TYPE=op
#Windows Domain Action
SLD_WINDOWS_DOMAIN_ACTION=skip
#XAPPs Certificate Action
XAPP_CERTIFICATE_ACTION=self
EOF

   chmod 400 "${FULLINSTPATH}/install.properties"
}


b1h_90_install_properties()
{
   # append more install properties
   cat >> "${FULLINSTPATH}/install.properties" <<-EOF
#Features selected for installation/unintallation/upgrade
SELECTED_FEATURES=B1ServerToolsSLD,B1ServerToolsLicense,B1ServerToolsMailer,B1ServerToolsXApp,B1ServerSHR,B1ServerCommonDB,B1ServerDemoDB_US,B1ServerHelp_EN,B1ServerAddons,B1ServerOI,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration
EOF
}


b1h_91_install_properties()
{
   # append more install properties
   cat >> "${FULLINSTPATH}/install.properties" <<-EOF
#Features selected for installation/unintallation/upgrade
SELECTED_FEATURES=B1ServerToolsSLD,B1ServerToolsLicense,B1ServerToolsMailer,B1ServerToolsXApp,B1ServerSHR,B1ServerCommonDB,B1ServerDemoDB_US,B1ServerHelp_EN,B1ServerAddons,B1ServerOI,B1AnalyticsOlap,B1AnalyticsTomcatEntSearch,B1AnalyticsTomcatDashboard,B1AnalyticsTomcatReplication,B1AnalyticsTomcatConfiguration,B1ServiceLayerComponent,B1ServerToolsExtensionManager
#Service Layer load balancer member(s)
SL_LB_MEMBERS=127.0.0.1:50001,127.0.0.1:50002,127.0.0.1:50003
#Install Service Layer load balancer member(s) only
SL_LB_MEMBER_ONLY=false
#Service Layer load balancer port number
SL_LB_PORT=50000
#Maximum threads per Sevice Layer load balancer memeber
SL_THREAD_PER_SERVER=30
EOF
}

b1h_92_install_properties()
{
   # append more install properties
   cat >> "${FULLINSTPATH}/install.properties" <<-EOF
#Compress backups
BCKP_BACKUP_COMPRESS=false
#Limit size of backups (in MBs)
BCKP_BACKUP_SIZE_LIMIT=
#Log files location
#BCKP_PATH_LOG=
#Backup location
#BCKP_PATH_TARGET=
#Working folder
#BCKP_PATH_WORKING=
#Remove databases of features during uninstallation
#FEATURE_DATABASES_TO_REMOVE=
#HANA DB Admin ID
HANA_DATABASE_ADMIN_ID=${sid}adm
#HANA DB Admin Password
HANA_DATABASE_ADMIN_PASSWORD=${MASTERPASS}
#HANA DB server will be restarted after installation/uninstallation
HANA_OPTION_RESTART=true
#Remove SLD Database during uninstallation
HANA_SLD_DATABASE_UNINSTALL_REMOVE=true
EOF
}


b1h_enable_hdb_scriptserver()
{
    # activate HANA script server for B1 features.
    # will be enabled after next HANA restart
    # either by b1h_restart_hana() or B1H 9.2 native installer
    sid=`echo $SID | tr '[:upper:]' '[:lower:]'`
    su - ${sid}adm -c "hdbsql -i ${SAPINSTNR} -u ${DB_USER} -p ${MASTERPASS} -jC \"alter system alter configuration ('daemon.ini','SYSTEM') set ('scriptserver','instances') = '1' with reconfigure\"" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
       yast_popup_wait "Could not activate HANA script server, please activate manually"
    fi
}


b1h_restart_hana()
{
    # restart HANA to activate B1 features
    sid=`echo $SID | tr '[:upper:]' '[:lower:]'`
    su - ${sid}adm -c "HDB stop > /dev/null 2>&1"
    if [ $? -eq 0 ]; then
       su - ${sid}adm -c "HDB start > /dev/null 2>&1"
       if [ $? -eq 0 ]; then
          yast_popup_timed "SAP HANA has been restarted to activate SAP Business One features."
       else
          yast_popup_wait "Could not restart HANA instance nr ${SAPINSTNR}. Please restart SAP HANA to activate SAP BusinessOne features."
       fi
    else
       yast_popup_wait "Could not stop HANA instance nr ${SAPINSTNR}. Please restart SAP HANA to activate SAP BusinessOne features."
    fi
}


b1h_restart_sld()
{
    # restart B1 SLD service
    /etc/init.d/sapb1servertools restart > /dev/null 2>&1
    if [ $? -ne 0 ]; then
       yast_popup_wait "Could not restart SAP Business One SLD service, please restart manually"
    fi
}


b1h_installation()
{
    local rc=0
    B1_PRODUCT="SAP Business One,\n version for SAP HANA"
    B1H_version=`head -2 ${SAPCD_INSTMASTER}/info.txt | tail -1 | cut -c1,2`   
    # different directory paths in B1 9.0 and 9.1
    INSTPATH_90='Packages Linux/ServerComponents'
    INSTPATH_91='Packages.Linux/ServerComponents'

    if [ -d "${SAPCD_INSTMASTER}/${INSTPATH_91}/" ]; then
       FULLINSTPATH=${SAPCD_INSTMASTER}/${INSTPATH_91}
    else
       if [ -d "${SAPCD_INSTMASTER}/${INSTPATH_90}/" ]; then
          FULLINSTPATH=${SAPCD_INSTMASTER}/${INSTPATH_90}
       else
          yast_popup_wait "Cannot install BusinessOne ServerComponents:\npath not found:\n${FULLINSTPATH}"
          rc=1
          return $rc
       fi
    fi

    INSTTOOL_91=install.bin
    INSTTOOL_92=install
    if [ -f "${FULLINSTPATH=}/${INSTTOOL_92}" ]; then
       INSTTOOL=${INSTTOOL_92}
       if [ -f "${FULLINSTPATH}/Wizard/setup.sh" ]; then
          chmod +x ${FULLINSTPATH}/Wizard/setup.sh
       fi
    else
       INSTTOOL=${INSTTOOL_91}
    fi
    chmod +x ${FULLINSTPATH}/${INSTTOOL}

    USER_INSTALL_LOGS=/var/log/SAPBusinessOne/B1Installer*.log
    if [ ! -f "${FULLINSTPATH}/${INSTTOOL}" ]; then
       yast_popup_wait "Cannot install BusinessOne ServerComponents:\npath to installation tool not found:\n${FULLINSTPATH}/${INSTTOOL}"
       rc=1
       return $rc
    else
       b1h_install_parameters
       cd "${FULLINSTPATH}"
       [ -x /sbin/yast2 ] && /sbin/yast2 ${tmpfile}
       if [ $? -eq 0 ]; then
          # start unattended installation with default parameters
          b1h_install_properties
          if [ "${B1H_version}" == "90" ];then b1h_90_install_properties; fi
          if [ "${B1H_version}" == "91" ];then b1h_91_install_properties; fi
          if [ "${B1H_version}" == "92" ];then b1h_91_install_properties; b1h_92_install_properties; fi
          ./${INSTTOOL} -i silent -f ./install.properties > /dev/null 2>&1 &
          pid_installer=$!
          while [ ! -f ${USER_INSTALL_LOGS} ]; do sleep 1; done
          tail -f ${USER_INSTALL_LOGS} &
          pid_logging=$!
          wait ${pid_installer}
          rc=$?
          kill -9 ${pid_logging}
          if [ $rc -eq 0 ]; then
             # B1H 9.2 restarts HANA so we only do it for prior versions
             if [ "${B1H_version}" -lt "92" ];then b1h_restart_hana; fi
             b1h_restart_sld
          else
             yast_popup_wait "Installation of SAP Business One ServerComponents finished with error code ${rc}.\nFor details please check log file at ${USER_INSTALL_LOGS}"
             rc=1
          fi
       else
          # run B1 wizard to customize installation parameters
          ./${INSTTOOL} > /dev/null 2>&1
          rc=$?
          # re-read B1H installation folder because it may have been customized
          INSTALL_PROPERTIES=`find / -name .installer.properties`
          if [ -n "${INSTALL_PROPERTIES}" ]; then
              USER_INSTALL_DIR=`grep INSTALLATION_FOLDER ${INSTALL_PROPERTIES} | awk -F'=' '{print $NF}'`
          fi
          if [ $rc -ne 0 ]; then
             yast_popup_wait "Installation of SAP Business One ServerComponents finished with error code ${rc}.\nFor details please check log file at ${USER_INSTALL_LOGS}"
             rc=1
          fi
       fi
       rm ${tmpfile}
    fi
    return $rc
}


b1a_installation()
{ 
    local rc=0
    B1_PRODUCT="SAP Business One\n analytics powered by SAP HANA"
    INSTPATH1=InstData/VM/install/Disk1/InstData/VM
    INSTPATH2=InstData/VM
    INSTTOOL=install.bin
    FULLINSTPATH=${SAPCD_INSTMASTER}/${INSTPATH1}
    if [ ! -f "${FULLINSTPATH}/${INSTTOOL}" ]; then
       FULLINSTPATH=${SAPCD_INSTMASTER}/${INSTPATH2}
    fi
    if [ ! -f "${FULLINSTPATH}/${INSTTOOL}" ]; then
       yast_popup_wait "Cannot install BusinessOne Analytics:\npath to installation tool not found:\n${FULLINSTPATH}/${INSTTOOL}"
       rc=1
    else
       if [ -f "${FULLINSTPATH}/install.properties" ]; then
          jreHome=`grep jreHome "${FULLINSTPATH}/install.properties" | cut -d "=" -f2`
          USER_INSTALL_DIR=`grep USER_INSTALL_DIR "${FULLINSTPATH}/install.properties" | cut -d "=" -f2`
          USER_INSTALL_LOGS=${USER_INSTALL_DIR}/logs/B1Installer.log

          # replace installation properties
          sed -i s/DB_USER=.*$/DB_USER=${DB_USER}/ "${FULLINSTPATH}/install.properties"
          sed -i s/HANA_INSTANCE_NUMBER=.*$/HANA_INSTANCE_NUMBER=${SAPINSTNR}/ "${FULLINSTPATH}/install.properties"
          # run installation tool
          cd "${FULLINSTPATH}"
          "${FULLINSTPATH}/${INSTTOOL}" -i silent -Dsystem_pwd=${MASTERPASS} > /dev/null 2>&1
          if [ $? -ne 0 ]; then
             yast_popup_wait "Installation of SAP Business One Analytics failed.\nFor details please check log file at ${USER_INSTALL_LOGS}"
             rc=1
          fi
       else
          yast_popup_wait "Cannot install SAP Business One Analytics:\nno install.properties found at ${FULLINSTPATH}"
          rc=1
       fi
    fi
    return $rc
}


###########################################
# Main
###########################################
   rc=0
   WORKDIR=/tmp
   DB_USER=SYSTEM
   USER_INSTALL_DIR=/usr/sap/SAPBusinessOne
   A_SID="/dev/shm/ay_q_sid"
   A_SAPINSTNR="/dev/shm/ay_q_sapinstnr"
   A_MASTERPASS="/dev/shm/ay_q_masterpass"
   TMPDIR=`mktemp -t -d sap_install_XXXXX`

   # check if HANA processes are running
   ps aux | grep -v grep | grep hdbindexserver > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      yast_popup_wait "SAP HANA is not running, please start it now. If SAP HANA is not yet installed, please install it now. Afterwards install SAP Business One."
      cleanup
      exit
   fi

   # get parameters from previous HANA installation
   [ -f ${A_SID} ] && SID=`< ${A_SID}` && rm ${A_SID}
   SID=${SID:="NDB"}
   [ -f ${A_SAPINSTNR} ] && SAPINSTNR=`< ${A_SAPINSTNR}` && rm ${A_SAPINSTNR}
   SAPINSTNR=${SAPINSTNR:="00"}
   [ -f ${A_MASTERPASS} ] && MASTERPASS=`< ${A_MASTERPASS}` && rm ${A_MASTERPASS}

   if [ -f ${A_MASTERPASS} ];then
       MASTERPASS=`< ${A_MASTERPASS}`
       rm ${A_MASTERPASS}
   else
       if [ -f ${MEDIA_TARGET}/ay_q_masterpass ]; then
           MASTERPASS=`< ${MEDIA_TARGET}/ay_q_masterpass`
       else
           yast_popup_wait "No Master password found for silent installer"
           cleanup
           return
       fi
   fi

   # Starting with B1 9.1 the default install location moves to /usr/sap so let's prepare this
   mkdir -p /usr/sap
   if [ ! -h /opt/sap ]; then
         ln -s /usr/sap /opt/sap
   fi

   case "${SAPINST_PRODUCT_ID}" in
      B1A)
        b1a_installation
        rc=$?
        ;;
      B1AH|B1H)
        b1h_enable_hdb_scriptserver
        b1h_installation
        rc=$?
        ;;
   esac

   if [ $rc -eq 0 ]; then
      b1_installation_summary
   fi
   cleanup
   return $rc
