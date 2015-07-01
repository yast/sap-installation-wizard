#!/bin/bash

# liste aus nstallation-wizard.xm
for PROD in AS-ABAP ASCS-ABAP DBI-ABAP PRAS-ABAP Webdispatcher GATEWAY TREX
do

echo '<?xml version="1.0"?>
<!DOCTYPE profile>
<profile xmlns="http://www.suse.com/1.0/yast2ns" xmlns:config="http://www.suse.com/1.0/configns">
<general>
  <ask-list config:type="list">
  ' > ../src/include/$PROD.xml


case "$PROD" in
	AS-ABAP)
		for i in VIRT_NETWORK TSHIRT
		do
			cat $i.xml >> ../src/include/$PROD.xml
		done
		;;
	ASCS-ABAP)
		for i in VIRT_NETWORK TSHIRT
		do
			cat $i.xml >> ../src/include/$PROD.xml
		done
		;;
	DBI-ABAP)
		for i in VIRT_NETWORK TSHIRT
		do
			cat $i.xml >> ../src/include/$PROD.xml
		done
		;;
	PRAS-ABAP)
		for i in VIRT_NETWORK TSHIRT
		do
			cat $i.xml >> ../src/include/$PROD.xml
		done
		;;
	*)
		echo "No ask dialog for $PROD."
		;;
esac

echo ' </ask-list>
</general>' >> ../src/include/$PROD.xml
if [ -e $PROD.post-packages.xml ]; then
	cat $PROD.post-packages.xml >> ../src/include/$PROD.xml
else
	cat post-packages.xml >> ../src/include/$PROD.xml
fi
echo '</profile>' >> ../src/include/$PROD.xml
#now we check if it is OK
xmllint --noout ../src/include/$PROD.xml 
done
