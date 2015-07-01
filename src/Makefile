install:
	install -d $(DESTDIR)/etc/init.d/
	install -d $(DESTDIR)/etc/sysconfig/
	install -d $(DESTDIR)/usr/share/YaST2/clients/
	install -d $(DESTDIR)/usr/share/applications/YaST2/
	install -d $(DESTDIR)/usr/share/YaST2/scrconf/
	install -d $(DESTDIR)/usr/share/YaST2/modules/
	install -d $(DESTDIR)/var/adm/fillup-templates/
	install -d $(DESTDIR)/usr/share/YaST2/include/sap-installation-wizard/
	install -d $(DESTDIR)/usr/lib/YaST2/bin/
	install -m 644 include/* $(DESTDIR)/usr/share/YaST2/include/sap-installation-wizard/
	install -m 644 clients/* $(DESTDIR)/usr/share/YaST2/clients/
	install -m 644 modules/* $(DESTDIR)/usr/share/YaST2/modules/
	install -m 644 desktop/sap-installation-wizard.desktop $(DESTDIR)/usr/share/applications/YaST2/
	install -m 644 scrconf/cfg_sap-installation-wizard.scr $(DESTDIR)/usr/share/YaST2/scrconf/
	install -m 644 misc/sap-installation-wizard     $(DESTDIR)/var/adm/fillup-templates/sysconfig.sap-installation-wizard
	install -m 644 misc/sap-installation-wizard.xml $(DESTDIR)/etc/
	echo "TODO install -m 755 boot.sles4sap      $(DESTDIR)/etc/init.d/"
	echo "TODO install -m 755 check_sap_uname.sh $(DESTDIR)/usr/lib/YaST2/bin/"

