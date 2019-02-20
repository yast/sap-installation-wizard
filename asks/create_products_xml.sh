#!/bin/bash
DIR=$1
# liste aus nstallation-wizard.xm
for PROD in STD DIST-ASCS DIST-DB DIST-APP1 HA-ERS Webdispatcher GATEWAY TREX
do

echo '<?xml version="1.0"?>
<!DOCTYPE profile>
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
<general>
  <mode>
    <final_restart_services config:type="boolean">
      false
    </final_restart_services>
  </mode>
  <ask-list config:type="list">
  ' > ../$DIR/include/$PROD.xml


case "$PROD" in
	STD)
		for i in masterPwd sid 
		do
			cat $i.xml >> ../$DIR/include/$PROD.xml
		done
		;;
	DIST-ASCS)
		for i in masterPwd sid ascsVirtualHostname instanceNumber scsVirtualHostname
		do
			cat $i.xml >> ../$DIR/include/$PROD.xml
		done
		;;
	DIST-DB)
		for i in masterPwd sid dbsid
		do
			cat $i.xml >> ../$DIR/include/$PROD.xml
		done
		;;
	DIST-APP1)
		for i in masterPwd ascsVirtualHostname ciVirtualHostname scsVirtualHostname dbsid instanceNumber profileDir
		do
			cat $i.xml >> ../$DIR/include/$PROD.xml
		done
		;;
#	GATEWAY)
#		for i in MY_MASTERPASS MY_GW_INSTANCE_NR
#		do
#			cat $i.xml >> ../$DIR/include/$PROD.xml
#		done
#		;;
#	Webdispatcher)
#		for i in MY_MASTERPASS MY_WD_ICF_CONFIG MY_WD_MS_PARAM MY_WD_PARAM
#		do
#			cat $i.xml >> ../$DIR/include/$PROD.xml
#		done
#		;;
	TREX)
		for i in masterPwd sid instanceNumber
		do
			cat $i.xml >> ../$DIR/include/$PROD.xml
		done
		;;
	*)
		echo "No ask dialog for $PROD."
		;;
esac

echo ' </ask-list>
</general>' >> ../$DIR/include/$PROD.xml
if [ -e $PROD.post-packages.xml ]; then
	cat $PROD.post-packages.xml >> ../$DIR/include/$PROD.xml
else
	cat post-packages.xml >> ../$DIR/include/$PROD.xml
fi
echo '</profile>' >> ../$DIR/include/$PROD.xml
#now we check if it is OK
xmllint --noout ../$DIR/include/$PROD.xml 
done
