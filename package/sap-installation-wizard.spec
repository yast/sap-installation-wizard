#
# spec file for package sap-installation-wizard
#
# Copyright (c) 2023 SUSE LINUX GmbH, Nuernberg, Germany.
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
Version:        4.4.15
Release:        0
PreReq:         /bin/mkdir %fillup_prereq yast2
Requires:       autoyast2
Requires:       autoyast2-installation
Requires:       rubygem(%{rb_default_ruby_abi}:nokogiri)
Requires:     	xfsprogs
%if ! %{defined sap_bone}
Requires:       HANA-Firewall
Requires:       saptune
Requires:       sap-netscape-link
Requires:       saprouter-systemd
Requires:       yast2-hana-firewall
Requires:       yast2-sap-scp
Requires:       yast2-sap-scp-prodlist
%else
PreReq:         logrotate
PreReq:         sapconf
%endif
Source:         %{name}-%{version}.tar.bz2
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildRequires:  autoyast2-installation
BuildRequires:	rubygem(%{rb_default_ruby_abi}:nokogiri)
BuildRequires:  rubygem(%{rb_default_ruby_abi}:parallel_tests)
BuildRequires:  sapconf
BuildRequires:  yast2
BuildRequires:  yast2-devtools >= 4.2.2
BuildRequires:  rubygem(%{rb_default_ruby_abi}:rspec)
BuildRequires:  rubygem(%rb_default_ruby_abi:yast-rake)
BuildRequires:  yast2-network
BuildRequires:  yast2-ruby-bindings >= 4.0.6
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
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"
%ifarch ppc64le
   sed -i /libopenssl0_9_8/d %{buildroot}/usr/share/YaST2/data/y2sap/HANA.xml 
%endif
#Make symlink for compatibility reason
cd %{buildroot}/%{yast_clientdir}
ln -s sap_installation_wizard.rb sap-installation-wizard.rb

%post
%{fillup_only -n sap-installation-wizard}
%if  %{defined sap_bone}
%{fillup_only -n pm-profiler}
%{fillup_only -n sapconf}
sed -i -e 's/^PERF_BIAS=*$/PERF_BIAS=performance/' -e 's/^GOVERNOR=*$/GOVERNOR=performance/' /etc/sysconfig/sapconf
/usr/bin/systemctl enable sapconf
cp /usr/share/YaST2/data/y2sap/logrotate-BOne /etc/logrotate.d/BOne
mkdir -p /etc/systemd/logind.conf.d/
cp /usr/share/YaST2/data/y2sap/logind.conf.d-sap.conf /etc/systemd/logind.conf.d/sap.conf
%endif

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
%doc src/docs/windows_cheat_sheet.pdf src/docs/sap-autoinstallation.txt src/docs/hana-autoyast.xml README README.md
%license COPYING

%changelog
