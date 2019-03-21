######################################################################################################################################################################################################
#                                                                                                                                                                                                    #
# Installation service 'SAP NetWeaver 7.4 Support Release 2 > MaxDB > SAP Systems > Application Server ABAP > High-Availability System > ASCS Instance', product id 'NW_ABAP_ASCS:NW740SR2.ADA.PIHA' #
#                                                                                                                                                                                                    #
######################################################################################################################################################################################################

# USED PARAMETERS ##masterPwd## ##sid## ##ascsVirtualHostname## ##instanceNumber## ##scsVirtualHostname##

# Password for the Diagnostics Agent specific <dasid>adm user. Provided value may be encoded.
DiagnosticsAgent.dasidAdmPassword = 

# Windows domain in which the Diagnostics Agent users must be created.
# The property is Microsoft Windows only. This is an optional property.
DiagnosticsAgent.domain = 

# Password for the Diagnostics Agent specific SAPService<DASID> user. Provided value may be encoded.
# The property is Microsoft Windows only.
DiagnosticsAgent.sapServiceDASIDPassword = 

NW_GetMasterPassword.masterPwd = ##masterPwd##

# Human readable form of the Default Login language - used for instance in the preselection in SAPGUI. This Parameter is potentially asked in addition in the dialog that also asks for the SID. It is not asked in all these dialogs, but only in systems that have ( potentialy beside others ) an ABAP stack. It is asked for installation but not for system copy. It is asked in those installations, that perform the ABAP load. That could be the Database Load installation in case of a distributed scenario, or in the Standard Installer, that is not distributed at all. This Parameter is saved in the Default Profile. It has no influence on Language settings in a Java Stack. Valid names are stored in a table of the subcomponent NW_languagesInLoadChecks. The available languages must be declared in the LANGUAGES_IN_LOAD parameter of the product.xml . In this file the one character representation of the languages is used. Check the same table in the subcomponent mentioned above.
NW_GetSidNoProfiles.SAP_GUI_DEFAULT_LANGUAGE = 

# The drive to use (windows only)
NW_GetSidNoProfiles.sapdrive = 

# The /sapmnt path (unix only)
NW_GetSidNoProfiles.sapmnt = /sapmnt

# The SAP System ID of the system to install
NW_GetSidNoProfiles.sid = ##sid##

# Will this system be unicode system?
NW_GetSidNoProfiles.unicode = true

NW_SCS_Instance.ascsInstanceNumber = 

NW_SCS_Instance.ascsVirtualHostname = ##ascsVirtualHostname##

NW_SCS_Instance.instanceNumber = ##instanceNumber##

NW_SCS_Instance.scsInstanceNumber = 

NW_SCS_Instance.scsMSPort = 

NW_SCS_Instance.scsVirtualHostname = ##scsVirtualHostname##

NW_System.installSAPHostAgent = true

NW_adaptProfile.templateFiles = 

# The FQDN of the system.
NW_getFQDN.FQDN = 

# Do we want to set the FQDN for the system?
NW_getFQDN.setFQDN = false

# The path to the jce policy archive to install into the java home directory if it is not already installed.
NW_getJavaHome.jcePolicyArchive = 

hostAgent.domain = 

# Password for the SAP Host Agent specific sapadm user. Provided value may be encoded.
hostAgent.sapAdmPassword = 

nwUsers.sapDomain = 

nwUsers.sapServiceSIDPassword = 
nwUsers.sidadmPassword = des24(140|122|126|11|224|60|251|166|156|194|66|124|97|97|239|241|137|105|204|91|254|)
