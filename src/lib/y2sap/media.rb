# encoding: utf-8
  
# Copyright (c) [2018] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

require "yast"
require "ui/dialog"
require "y2sap/configuration/media"
require "y2sap/media/copy"
require "y2sap/media/dialog"
require "y2sap/media/complex"
require "y2sap/media/find"
require "y2sap/media/mount"

module Y2Sap
  class Media < Y2Sap::Configuration::Media
    include Yast
    include Yast::Logger
    include Yast::I18n
    include Y2Sap::MediaCopy
    include Y2Sap::MediaDialog
    include Y2Sap::MediaComplex
    include Y2Sap::MediaFind
    include Y2Sap::MediaMount
    def initialize
      textdomain "sap-installation-wizard"
      super
    end
  end
end
