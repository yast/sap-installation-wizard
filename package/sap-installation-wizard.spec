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
Version:        4.2.8
Release:        0
PreReq:         /bin/mkdir %insserv_prereq %fillup_prereq yast2
BuildRequires:  yast2
Requires:       HANA-Firewall
Requires:       autoyast2
Requires:       autoyast2-installation
Requires:	ruby2.5-rubygem-nokogiri
Requires:	xfsprogs
%if ! %{defined _SAPBOne}
Requires:       sap-netscape-link
Requires:       saprouter-systemd
Requires:       yast2-hana-firewall
Requires:       yast2-sap-scp
Requires:       yast2-sap-scp-prodlist
Requires:       saptune
Requires:       yast2-saptune
%endif
Source:         %{name}-%{version}.tar.bz2
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  ruby2.5-stdlib
BuildRequires:	ruby2.5-rubygem-nokogiri
BuildRequires:  autoyast2-installation
BuildRequires:  yast2-network
BuildRequires:  yast2-ruby-bindings >= 4.0.6
BuildRequires:  rubygem(rspec)
BuildRequires:  rubygem(yast-rake)
BuildRequires:  yast2-devtools
# speed up the tests in SLE15-SP1+ or TW
%if 0%{?sle_version} >= 150100 || 0%{?suse_version} > 1500
BuildRequires:  rubygem(%{rb_default_ruby_abi}:parallel_tests)
%endif
ExclusiveArch:  x86_64 ppc64le
Obsoletes:      sap-media-changer <= 2.17
Provides:       sap-media-changer  = %{version}

%description
A YaST module providing an installation wizard for SAP applications

Authors:
--------
    varkoly@suse.com

%prep
%setup -q

%check
#rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"
%ifarch ppc64le
   sed -i /libopenssl0_9_8/d %{buildroot}/usr/share/YaST2/data/y2sap/HANA.xml 
%endif

%post
%{fillup_only -n sap-installation-wizard}

%preun

%postun

%clean
rm -rf  %{buildroot}

%files
%defattr(-,root,root)
%{yast_clientdir}
%{yast_libdir}
%{yast_desktopdir}
%{yast_fillupdir}
%{yast_ybindir}
%{yast_scrconfdir}
%{yast_icondir}
/usr/share/YaST2/data/y2sap/
%if ! %{defined _SAPBOne}
%doc windows_cheat_sheet.pdf sap-autoinstallation.txt hana-autoyast.xml README README.md
%else
%doc README README.md
%endif
%license COPYING

%changelog
