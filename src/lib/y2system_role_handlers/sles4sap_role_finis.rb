# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2020 SUSE LLC
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact SUSE.
#
# To contact SUSE about this file by physical or electronic mail, you may find
# current contact information at www.suse.com.
# ------------------------------------------------------------------------------

require "yast"
require "y2firewall/firewalld"
require "installation/finish_client"

module Y2SystemRoleHandlers
    class Sles4SapRoleFinish
       include Yast::Logger
       def run
            role = ::Installation::SystemRole.current_role
            if !role
               log.warn("Current role not found, not saving the config")
               return
            end
            return true if !@firewalld.installed?
            if Service.Enabled("xrdp")
                external = @firewalld.find_zone(@firewalld.default_zone)
                external.add_service("ms-wbt")
                @firewalld.write
            end
            true
       end
    end
end
