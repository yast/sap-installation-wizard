# encoding: utf-8
  
# ------------------------------------------------------------------------------
# Copyright (c) 2016 SUSE Linux GmbH, Nuernberg, Germany.
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
# Summary: SUSE High Availability Setup for SAP Products: Base configuration class


require_relative 'base_config'

module Y2Sap
  module Configuration
    # @return [String] The url to the media
    attr_accessor :location_cache

    # @return [String] The url schema to the media
    attr_accessor :schema

    class Media < BaseConfig
      def initialize
	 @location_cache = "nfs.server.com/directory/"
	 @schema = "nfs"
      end
    end
  end
end

