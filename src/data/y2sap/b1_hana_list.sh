#!/bin/bash
# b1_hana_inst.sh - is a script used to list available HANA DBs for SAP Business One installations.
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

# get a list of installed HANA DBs
all_sid_arr=(`ls -1 /hana/data/`)

# checking which one is running
echo -n '<selection config:type="list">'
for i in "${all_sid_arr[@]}"
do
    ps aux | grep  -v grep | grep hdbindexserver | grep ${i,,} > /dev/null 2>&1
    #echo $?
    if [ $? -eq 0 ]; then
        inst_nr=`ls -1 /usr/sap/$i/ | grep HDB | cut -c 4-`
        echo -n "<entry><value>$i:$inst_nr</value><label>$i:$inst_nr</label></entry>"
    fi
done
#return the results
echo -n "</selection>"
