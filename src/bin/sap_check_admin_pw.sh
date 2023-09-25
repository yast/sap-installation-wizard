#!/bin/bash

PRODUCT=$1
if [ -e /var/run/sap-wizard/ay_q_masterPwd ]; then
	pass=$( cat /var/run/sap-wizard/ay_q_masterPwd )
else
	read pass
fi

func crack_check {
	if [  "$( echo "${pass}" | /usr/sbin/cracklib-check | gawk '{ print $2 }' )" != "OK" ]; then
		echo "Password is not secure enough"
		exit 1
	fi
}

minLen=8
allowed="a-zA-Z0-9\!\@\#\$\%\^\&\*\(\)\_\+"
notAllowedForBone="<
>
\
&
javascript:
vbscript:
(
)
expression(*)
eval(*)
src=
%28
%29"

if [ -e /usr/share/doc/packages/patterns-sap/bone.txt ]; then
	PRODUCT="B1"
fi

case "$PRODUCT" in
	B1)
		notAllowedStrings=${notAllowedForBone}
		;;
	NW)
		minLen=3
		maxLen=40
	*)
		notAllowedStrings=""
esac

for bad in $notAllowedStrings
do
	if [[ "$pass" =~ "${bad}" ]]; then
		echo "The password contains not allowed string."
		exit 1
	fi
done

if [ -z "$pass" ]; then
        echo "You must provide a master password for your installation!"
        exit 1
fi
if [ "${#pass}" -lt $minLen ]; then
        echo "The master password cannot be shorter than $minLen chars."
        echo "You entered a ${#pass} chars long password."
        exit 1
fi
if [ "$maxLen" -a "${#pass}" -gt $maxLen ]; then
        echo "The master password cannot be longer than $maxLen chars."
        echo "You entered a ${#pass} chars long password."
        exit 1
fi
if [ -n "${pass//[${allowed}]}" ]; then
        echo "The password contains forbidden chars."
        echo "Allowed are 0-9, A-Z, a-z and $ _ # :"
        echo "But you're using: '${pass//[${allowed}]/}'."
        exit 1
fi
[[ "$pass" =~ [A-Z] ]] || {
        echo "The password must at least contain one uppercase character A-Z."
        exit 1
}
[[ "$pass" =~ [a-z] ]] || {
        echo "The password must at least contain one lowercase character a-z."
        exit 1
}
[[ "$pass" =~ [0-9] ]] || {
        echo "The password must at least contain one digit 0-9."
        exit 1
}
[[ "$pass" =~ [\!\@\#\$\%\^\&\*\(\)\_\+] ]] || {
        echo "The password must at least contain one special character '! @ # $ % ^ & * () _ +' ."
        exit 1
}
if [ "$( echo "$pass" | grep -E '^(\w)\1{2}' )" ]; then
        echo "The password must not start with 3 identical characters."
	exit 1
fi
[[ "$pass" =~ ^[!?] ]] && {
	echo "The password must not start with ? or !"
	exit 1
}

