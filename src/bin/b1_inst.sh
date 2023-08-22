#!/bin/bash -x

# b1_inst.sh - is a script used to install SAP Business One products:
#   SAP Business One 9.2, version for SAP HANA including SAP Business One Analytics Powered by SAP HANA
#
# Copyright (c) 2017 SAP AG
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

usage() {
	cat <<-EOF

		############################################################################
		#  $(basename $0) -i | -m | -d | -s | -n | -p | -t                         #
		#                                                                          #
		#  m ) SAPCD_INSTMASTER - Path to the SAP Installation Master Medium       #
		#  d ) SAPINST_DIR - The directory where the installation will be prepared #
		#  s ) SID - SAP System ID                                                 #
		#  n ) SAPINSTNR - SAP Instance Number (two digits)                        #
		#  p ) MASTERPASS - SAP Masterpassword to use                              #
		#  h ) This help                                                           #
		#                                                                          #
		############################################################################
EOF
	echo
}

SAPCD_INSTMASTER=""

# Optionally overrule parameters from answer files by command line arguments
while getopts "m:i:y:d:s:n:p:t:h\?" options; do
	case $options in
		m ) SAPCD_INSTMASTER=${OPTARG};; # Path to the SAP Installation Master Medium (has to be full-qualified)
		i ) continue;; # On B1 we ignore product id
		y ) continue;; # On B1 we ignore product type
		d ) SAPINST_DIR=${OPTARG};; # The directory where the installation will be prepared
		s ) SID=$OPTARG;;  # SAP System ID
		n ) SAPINSTNR=$OPTARG;;  # SAP Instance Number
		p ) MASTERPASS=$OPTARG;;  # Masterpassword
		t ) continue;; # On B1 we ignore DB type
		h | \? ) usage
		        exit $ERR_invalid_args;;
		* ) usage
		        exit $ERR_invalid_args;;
	esac
done

###########################################
# globals
###########################################
TMPDIR=$(mktemp -t -d sap_install_XXXXX)
chmod 755 $TMPDIR
MEDIA_TARGET=$(dirname $SAPCD_INSTMASTER)

HOSTNAME=$(hostname)
IP_ADDR=$(gethostip -d $HOSTNAME)

# YaST parameter take over
A_MASTERPASS=$(cat "${MEDIA_TARGET}/ay_q_masterPwd")
A_SID=$(cat "${MEDIA_TARGET}/ay_q_sid" | cut -c1-3)
A_SAPINSTNR=$(cat "${MEDIA_TARGET}/ay_q_sid" | cut -c5-6)
if [ -z "${A_SAPINSTNR}" && -e ${MEDIA_TARGET}/ay_q_sapinstnr ]; then
  A_SAPINSTNR=$(cat "${MEDIA_TARGET}/ay_q_sapinstnr")
fi

###########################################
# Define ERRORS section
###########################################
#ERR_invalid_args=1

err_message[0]="Ok"
err_message[15]=""

###########################################
# Functions:
###########################################


yast_popup()
{
 if [ "$NOGUI" = "yes" ]; then
    echo $1
    return
 fi

# open a YaST popup with the given text
 local tmpfile
 tmpfile="${TMPDIR}/yast_popup.ycp"
 echo $tmpfile
 cat > ${tmpfile} <<-EOF
	{
	    import "Popup";
	    Popup::AnyTimedMessage ( "", "$1", 10 );
	}
EOF

    [ -x /sbin/yast2 ] && /sbin/yast2 ${tmpfile}
 rm ${tmpfile}
}

cleanup()
{
  if [ ! -e /root/b1-install-do-not-rm ]; then
    rm -rf /tmp/sapinst_exe.*
    rm -f  ${MEDIA_TARGET}/ay_*
    # the ^[ is a escape character "strg-v ESC" !! don't cut'n'paste it

    rm -rf ${MEDIA_TARGET}
    # delete since created via mktemp
    rm -rf ${TMPDIR}
  fi

}


summary()
{
        local tmpfile
        local summary_file

        summary_file="/root/installation${INSTALL_COUNT}_summary_${A_SID}.txt"
        tmpfile="${TMPDIR}/yast_popup_inst_summary.ycp"
	phys_ip=$( ip address show  | grep $IP_ADDR | gawk '{ print $2 }' )

        cat > ${summary_file} <<-EOF
        #########################################################################
        # The system BusinessOne for HANA is installed with the following parameters
        # ( File can be found here: ${summary_file} )
        #########################################################################
        # Hostname:	${HOSTNAME}
        # Domain Name:	$(dnsdomainname)
        # IP Address:	${phys_ip}
        # Domain Searchlist:	$(grep ^search /etc/resolv.conf | sed 's/search //')
        # IP for Nameserver:	$(grep ^nameserver /etc/resolv.conf | sed 's/nameserver //' | tr '\n' ' ')
        # Default Gateway:	$( ip route list | gawk '/default/ { print $3}' )
        #
        # SAP HANA System ID:	${A_SID}
        # SAP HANA Instance:	${A_SAPINSTNR}
        # Installation location: ${USER_INSTALL_DIR}
        #########################################################################
        # $(basename $0) ended at $(date +"%Y/%m/%d, %T (%Z)")
        #########################################################################
EOF

        cat > ${tmpfile} <<-EOF
                {
                        string headline="Installation Summary: ${B1_PRODUCT}";
                        import "Popup";

                        string source = (string) SCR::Read(.target.string, "${summary_file}");
                        Popup::ShowTextTimed (headline, source, 100);

                }
EOF

        /sbin/yast2 ${tmpfile}
        rm ${tmpfile}
}

preparation()
{
mkdir /usr/sap/SAPBusinessOne/
mkdir /var/log/SAPBusinessOne/
}

parameters()
{
    PROPERTIES="${MEDIA_TARGET}/b1h_properties"
    touch $PROPERTIES
    cat > $PROPERTIES <<-EOF
B1S_SAMBA_AUTOSTART=true
B1S_SHARED_FOLDER_OVERWRITE=true
BCKP_BACKUP_COMPRESS=true
HANA_DATABASE_USER_ID=SYSTEM
LANDSCAPE_INSTALL_ACTION=create
LICENSE_SERVER_ACTION=register
LICENSE_SERVER_NODE=standalone
SELECTED_FEATURES=B1ServerToolsSLD,B1ServerToolsExtensionManager,B1ServerToolsLicense,B1BackupService,B1ServerSHR,B1ServerCommonDB
SITE_USER_ID=B1SiteUser
SLD_CERTIFICATE_ACTION=self
SLD_DATABASE_ACTION=create
SLD_DATABASE_NAME=SLDDATA
SLD_SERVER_PROTOCOL=https
SLD_SERVER_TYPE=op
INSTALLATION_FOLDER=/usr/sap/SAPBusinessOne
INST_FOLDER_CORRECT_PERMISSIONS=true
#### flexible part ###
BCKP_HANA_SERVERS=<servers><server><system address="${IP_ADDR}"/><database instance="${A_SAPINSTNR}" port="3${A_SAPINSTNR}13" tenant-db="${A_SID}" user="SYSTEM" password="${A_MASTERPASS}"/></server></servers>
HANA_DATABASE_ADMIN_ID=${A_SID,,}adm
HANA_DATABASE_TENANT_DB=${A_SID}
HANA_DATABASE_INSTANCE=${A_SAPINSTNR}
HANA_DATABASE_SERVER_PORT=3${A_SAPINSTNR}13
HANA_DATABASE_SERVER=${IP_ADDR}
HANA_DATABASE_ADMIN_PASSWD=${A_MASTERPASS}
HANA_DATABASE_USER_PASSWORD=${A_MASTERPASS}
SITE_USER_PASSWORD=${A_MASTERPASS}
EOF

if [ $? -ne 0 ];
then
  yast_popup "Creating parameters file has failed."
fi

}

installation()
{
    local rc=0
    B1_PRODUCT="SAP Business One,\n version for SAP HANA"
    #if [ ! -d "${FULLINSTPATH}" ];
    #then
          #yast_popup "Cannot install BusinessOne ServerComponents:\npath not found:\n${INSTPATH}"
    #      rc=1
    #      return $rc
    #fi

    INSTTOOL="${MEDIA_TARGET}/Instmaster/Packages.Linux/ServerComponents/install"
    chmod +x ${INSTTOOL}

    USER_INSTALL_LOGS="/var/log/SAPBusinessOne/B1Installer*.log"
    if [ ! -f "${INSTTOOL}" ];
    then
       yast_popup "Cannot install BusinessOne ServerComponents:\npath to installation tool not found:\n${INSTTOOL}"
       rc=1
       return $rc
    else
          # start unattended installation with parameters
          preparation
          parameters
          ${INSTTOOL} -i silent -f ${PROPERTIES} > /dev/null 2>&1 &
          pid_installer=$!

          # start displaying the logs
	  while true
	  do
	        USER_INSTALL_LOG=$( find /var/log/SAPBusinessOne/ -maxdepth 1 -name "B1Installer*.log" )
		if [ "$USER_INSTALL_LOG" ]; then
		   break
		fi
		sleep 2
	  done

          tail -f ${USER_INSTALL_LOG} &
          pid_logging=$!

          # waiting for the installation to be done
          wait ${pid_installer}
          rc=$?

          # stop log monitor
          kill -9 ${pid_logging}
    fi
    return $rc
}

b1_post_process()
{
    # set samba security according to SAPNote 2359442
    smb_conf="/etc/samba/smb.conf"
    security_param="security=user"

    if [ -f "/etc/samba/smb.conf" ];
    then
	param_check=$(cat $smb_conf | grep ${security_param})
	
	    if [ -z "$param_check" ];
	    then
    	    sed -i '/\[global\]/,+0{ a \
	'${security_param}'
    	    }' $smb_conf
    	
    	    # restarting samba with the new configuration
    	    /usr/bin/systemctl restart smb.service
    	fi
    else
        yast_popup "Unable to find file smb.conf. Please find and adjust it manually according to the SAPNote 2359442."
    fi
}

###########################################
# Main
###########################################
  rc=0
  USER_INSTALL_DIR="/usr/sap/SAPBusinessOne"

  # check if HANA processes are running
  ps aux | grep -v grep | grep -i "/usr/sap/${A_SID}/...../exe/sapstartsrv" > /dev/null 2>&1
  if [ $? -ne 0 ];
  then
      yast_popup "SAP HANA ${A_SID} is not running, please start it now. If SAP HANA is not yet installed, please install it now. Afterwards install SAP Business One."
      cleanup
      exit
   else
      installation
      rc=$?
      if [ $rc -ne 0 ];
      then
         yast_popup "Installation failed. For the details, see the logs."
         cleanup
      else
         b1_post_process
         summary
         cleanup
      fi
   fi
   exit $rc
