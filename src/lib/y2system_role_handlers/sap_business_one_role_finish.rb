# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2022 SUSE LLC
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
  # Open xrdp port if xrdp.service was enabled.
  class SapBusinessOneRoleFinish
    include Yast::Logger
    def run
      log.info("SapBusinessOneRoleFinish started")
      role = ::Installation::SystemRole.current_role
      if !role
        log.warn("Current role not found, not saving the config")
        return
      end
      @firewalld = Y2Firewall::Firewalld.instance
      @firewalld.read
      return true if !@firewalld.installed?
      log.info("SapBusinessOneRoleFinish firewall installed")
      if ::Installation::Services.enabled.include?("xrdp")
        log.info("SapBusinessOneRoleFinish xrd enabled")
        external = @firewalld.find_zone(@firewalld.default_zone)
        external.add_service("ms-wbt")
        @firewalld.write
      end
      true
    end
  end
end
