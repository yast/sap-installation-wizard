#!/bin/bash

PRODUCT=$1
if [ -e /var/run/sap-wizard/ay_q_masterPwd ]; then
	pass=$( cat /var/run/sap-wizard/ay_q_masterPwd )
else
	read pass
fi

allowed="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#\$_:"
notAllowedStrings="javascript:
vbscript:
expression(*)
eval(*)
src=
%28
%29
"

if [ -z "$pass" ]; then
        echo "You must provide a master password for your installation!"
        exit 1
fi
if [ "${#pass}" -lt 8 ]; then
        echo "The master password cannot be shorter than 8 chars."
        echo "You entered a ${#pass} chars long password."
        exit 1
fi
if [ -n "${pass//[${allowed}]}" ]; then
        echo "The Password contains forbidden chars."
        echo "Allowed are 0-9, A-Z, a-z and $ _ # :"
        echo "But you're using: '${pass//[${allowed}]/}'."
        exit 1
fi
[[ "$pass" =~ [A-Z] ]] || {
        echo "The Password must at least contain one uppercase character A-Z."
        exit 1
}
[[ "$pass" =~ [a-z] ]] || {
        echo "The Password must at least contain one lowercase character a-z."
        exit 1
}
[[ "$pass" =~ [0-9] ]] || {
        echo "The Password must at least contain one digit 0-9."
        exit 1
}
[[ "$pass" =~ [\$_#:] ]] || {
        echo "The Password must at least contain one special character '\$ _ # :'."
        exit 1
}
for bad in $notAllowedStrings
do
	if [[ "$pass" =~ "${bad}" ]]; then
		echo "The password contains not allowed string."
		exit 1
	fi
done
