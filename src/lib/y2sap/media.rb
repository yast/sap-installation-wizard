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
require "y2sap/media/find"
require "y2sap/media/mount"
require "y2sap/media/complex"

module Y2Sap
  # Represent a class to handle the SAP installation media.
  # 
  # This class includes some modules created for the different functions
  # for handling of the SAP media
  #
  class Media < Y2Sap::Configuration::Media
    include Yast
    include Yast::Logger
    include Yast::I18n
    include Y2Sap::MediaCopy
    include Y2Sap::MediaDialog
    include Y2Sap::MediaComplex
    include Y2Sap::MediaFind
    include Y2Sap::MediaMount

    # Initialize the Y2Sap::Media class
    # * Execute the initialuze function of the super class Y2Sap::Configuration::Media
    # * Creates the @scheme_list containing the available schemes for the access 
    #   to the SAP media
    # * Initialize the global variable @location_cache
    def initialize
      textdomain "sap-installation-wizard"
      super
      @scheme_list = [
          Item(Id("local"), "dir://", true),
          Item(Id("device"), "device://", false),
          Item(Id("usb"), "usb://", false),
          Item(Id("nfs"), "nfs://", false),
          Item(Id("smb"), "smb://", false)
      ]
      # Detect how many cdrom we have:
      cdroms=`hwinfo --cdrom | grep 'Device File:' | sed 's/Device File://' | gawk '{ print $1 }' | sed 's#/dev/##'`.split
      if cdroms.count == 1
        @scheme_list << Item(Id("cdrom"), "cdrom://", false)
      elsif cdroms.count > 1
        i=1
        cdroms.each { |cdrom|
          @scheme_list << Item(Id("cdrom::" + cdrom  ), "cdrom" + i.to_s + "://", false)
          i = i.next
        }
      end
      @location_cache = ""
    end
  end
end
