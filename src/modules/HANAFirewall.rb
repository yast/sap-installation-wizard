# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE Linux GmbH.
#
# ------------------------------------------------------------------------------
#
# Summary: Manage HANA firewall configuration.
# Authors: Howard Guo <hguo@suse.com>

require "socket"
Yast.import "Package"
Yast.import "Service"

module Yast
    class HANAFirewallClass < Module
        include Yast::Logger
        def initialize
            textdomain "sap-installation-wizard"
        end
        
        # Return list of all service names as seen by name service switch.
        def GetNonHANAServiceNames
            return `getent services | cut -d ' ' -f 1 | uniq`.split(/\n/).sort
        end
        
        # Return list of all HANA service names as defined in /etc/hana-firewall.d/
        def GetAllHANAServiceNames
            oldcwd = Dir.getwd
            Dir.chdir("/etc/hana-firewall.d/")
            # The convention is to only name HANA service definition files with capital letters
            service_names = Dir.glob("[A-Z]*")
            Dir.chdir(oldcwd)
            # HANA_* denotes "all HANA services"
            return ["HANA_*"] + service_names.sort
        end

        # Read current HANA firewall global configuration and per-interface configuration.
        def Read
            # Global configuration are simple key-values
            # If new keys are introduced to the sysconfig file, remember to add them here.
            global_conf = {
                :hana_systems => SCR.Read(path(".sysconfig.hana-firewall.HANA_SYSTEMS")).to_s,
                # Both of these keys carry default value yes
                :open_all_ssh => SCR.Read(path(".sysconfig.hana-firewall.OPEN_ALL_SSH")).to_s.downcase.strip != "no",
                :enable_logging => SCR.Read(path(".sysconfig.hana-firewall.ENABLE_LOGGING")).to_s.downcase.strip != "no",
            }
            # Interface services are interface numbers VS name and services list
            iface_conf = {}
            max_iface_num = 0
            SCR.Dir(path(".sysconfig.hana-firewall")).each { |key|
                conf_key = ".sysconfig.hana-firewall." + key
                case key
                    when /^INTERFACE_[0-9]+$/
                        # An interface name may be used in more than one interface numbers.
                        iface_name = SCR.Read(path(conf_key))
                        iface_num = key.sub(/^INTERFACE_/, '').to_i
                        iface_svcs = SCR.Read(path(conf_key + "_SERVICES")).to_s.split(/\s+/)
                        if !iface_svcs.empty?
                            iface_conf[iface_num] = {:name => iface_name, :svcs => []} if !iface_conf[iface_num]
                            iface_conf[iface_num][:svcs] += iface_svcs
                            if iface_num > max_iface_num
                                max_iface_num = iface_num
                            end
                        end
                end
            }
            log.info "HANAFirewall.Read - /etc/sysconfig/hana-firewall is: " + global_conf.to_s
            log.info "HANAFirewall.Read - Interface services are: " + iface_conf.to_s
            return [global_conf, iface_conf, max_iface_num]
        end
        
        # Return list of interface names eligible for use with HANA.
        def GetEligibleInterfaceNames
            # Return all names excluding loopback.
            return Socket.getifaddrs.map{|i| i.name}.uniq.select{|name| !name.match(/^lo\d*$/)}.sort
        end

        # Write HANA firewall configuration files and immediately start HANA firewall service.
        def Write(global_conf, iface_conf)
            log.info "HANAFirewall.Write - global configuration is: " + global_conf.to_s
            log.info "HANAFirewall.Write - interface services are: " + iface_conf.to_s
            # Make sure HANA Firewall package is installed
            if !Package.Installed("HANA-Firewall")
                if !Package.DoInstall(["HANA-Firewall"])
                    Report.Error(_("Failed to install package 'HANA-Firewall'."))
                    return
                end
            end
            # Look for running HANA instances
            pids = `pgrep hdb.sap`.split(/\n/)
            if pids.empty?
                Report.Error(_("Cannot detect any running HANA instances.\n" +
                               "The firewall may not function properly.\n" +
                              "Please remember to manually re-configure HANA-Firewall."))
            end
            # Figure out SID and instance ID from the processes' working directory
            sys_names = []
            pids.each { |pid|
                cwd_segments = `cat /proc/#{pid}/cmdline`.strip.split(/\//)
                # It should look like /hana/shared/T00/HDB00/hana-02
                if cwd_segments.length > 5
                    # Combine SID T00 and instance number 00 (from HDB00, remove HDB)
                    sys_names += [cwd_segments[3] + cwd_segments[4].slice(3,2)]
                end
            }
            log.info "HANAFirewall.Write - detected HANA system names: " + sys_names.to_s
            SCR.Write(path(".sysconfig.hana-firewall.HANA_SYSTEMS"), sys_names.join(' '))
            # Write configuration
            SCR.Write(path(".sysconfig.hana-firewall.OPEN_ALL_SSH"), global_conf[:open_all_ssh] == true ? "yes" : "no")
            SCR.Write(path(".sysconfig.hana-firewall.ENABLE_LOGGING"), global_conf[:enable_logging] == true ? "yes" : "no")
            max_iface_num = 0
            iface_conf.each { |iface_num, val|
                if iface_num > max_iface_num
                    max_iface_num = iface_num
                end
                iface_name = val[:name]
                SCR.Write(path(".sysconfig.hana-firewall.INTERFACE_" + iface_num.to_s), iface_name)
                svcs = val[:svcs].join(' ')
                SCR.Write(path(".sysconfig.hana-firewall.INTERFACE_" + iface_num.to_s + "_SERVICES"), svcs)
            }
            # Wipe configuration of other keys
            (max_iface_num+1..10).each { |i|
                SCR.Write(path(".sysconfig.hana-firewall.INTERFACE_" + i.to_s), "")
                SCR.Write(path(".sysconfig.hana-firewall.INTERFACE_" + i.to_s + "_SERVICES"), "")
            }
            SCR.Write(path(".sysconfig.hana-firewall"), nil)
            
            # Enable and start daemon
            Service.Enable("hana-firewall")
            if !(Service.Active("hana-firewall") ? Service.Restart("hana-firewall") : Service.Start("hana-firewall"))
                Report.Error(_("Failed to activate 'hana-firewall' service."))
            end
            
        end
    end

    HANAFirewall = HANAFirewallClass.new
end