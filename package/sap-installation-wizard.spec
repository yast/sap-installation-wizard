#
# spec file for package sap-installation-wizard
#
# Copyright (c) 2018 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           sap-installation-wizard
Summary:        Installation wizard for SAP applications
License:        GPL-2.0+
Group:          System/YaST
Version:        4.2.1
Release:        0
PreReq:         /bin/mkdir %insserv_prereq %fillup_prereq yast2
BuildRequires:  yast2
Requires:       HANA-Firewall
Requires:       autoyast2
Requires:       sap-netscape-link
Requires:       saprouter-systemd
Requires:       yast2-hana-firewall
Requires:       yast2-sap-scp
Requires:       yast2-sap-scp-prodlist
Requires:	xfsprogs
Requires:       saptune
Requires:       yast2-saptune
Source:         %{name}-%{version}.tar.bz2
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
ExclusiveArch:  x86_64 ppc64le
Obsoletes:      sap-media-changer <= 2.17
Provides:       sap-media-changer  = %{version}

%description
A YaST module providing an installation wizard for SAP applications

Authors:
--------
    varkoly@suse.com
    hguo@suse.com

%prep
%setup -n %{name}-%{version}

%build

%post
%{fillup_only -n sap-installation-wizard}
#insserv boot.sles4sap

%preun

%postun

%clean
rm -rf  %{buildroot}

%install
make DESTDIR=%{buildroot} install
%ifarch ppc64le
   sed -i /libopenssl0_9_8/d %{buildroot}/usr/share/YaST2/include/sap-installation-wizard/HANA.xml 
%endif

%files
%defattr(-,root,root)
%license COPYING
%doc windows_cheat_sheet.pdf sap-autoinstallation.txt hana-autoyast.xml
%config /etc/sap-installation-wizard.xml
%{_datadir}/YaST2/
%{_fillupdir}/sysconfig.sap-installation-wizard
%defattr(0755,root,root)
%{_datadir}/applications/
/usr/sbin/start_sap_docker.sh

%changelog
