install:
	install -d $(DESTDIR)/etc/YaST2/
	install -d $(DESTDIR)/etc/profile.d/
	install -d $(DESTDIR)/etc/sysconfig/
	install -d $(DESTDIR)/usr/share/YaST2/clients/
	install -d $(DESTDIR)/usr/share/applications/YaST2/
	install -d $(DESTDIR)/usr/share/YaST2/scrconf/
	install -d $(DESTDIR)/usr/share/YaST2/modules/
	install -d $(DESTDIR)/var/adm/fillup-templates/
	install -d $(DESTDIR)/usr/share/YaST2/include/sap-installation-wizard/
	install -d $(DESTDIR)/usr/share/YaST2/lib/sap/
	install -d $(DESTDIR)/usr/lib/YaST2/bin/
	install -m 755 include/*sh  $(DESTDIR)/usr/share/YaST2/include/sap-installation-wizard/
	install -m 644 include/*xml $(DESTDIR)/usr/share/YaST2/include/sap-installation-wizard/
	install -m 644 lib/sap/* $(DESTDIR)/usr/share/YaST2/lib/sap/
	install -m 644 clients/* $(DESTDIR)/usr/share/YaST2/clients/
	install -m 644 modules/* $(DESTDIR)/usr/share/YaST2/modules/
	install -m 644 desktop/*.desktop $(DESTDIR)/usr/share/applications/YaST2/
	install -m 644 misc/sap-installation-wizard     $(DESTDIR)/var/adm/fillup-templates/sysconfig.sap-installation-wizard
	install -m 644 misc/sap-installation-wizard.xml $(DESTDIR)/etc/
	install -m 644 misc/firstboot.xml  $(DESTDIR)/etc/YaST2/firstboot-sap.xml
	install -m 744 misc/sap-profile.sh $(DESTDIR)/etc/profile.d/

