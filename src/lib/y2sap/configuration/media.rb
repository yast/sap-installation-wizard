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
# Summary: SUSE SAP Products Installation Module: Base configuration class

require "y2sap/configuration/base"
require "yast"

module Y2Sap
  module Configuration
    class Media < Base
      # @return [String] In this directory will be installed the next sap product
      attr_reader :inst_dir

      # @return [String] The product counter.
      attr_accessor :product_count

      #@return [String] The url to the media
      attr_accessor :location_cache

      # @return [String] The full path to the directory which should be copied.
      # This can be different from mount_point if mounting device cdrom or local directory
      attr_accessor :source_dir

      # @return [Boolean] The full path to the media. This can be different from mount_point
      # if mounting device cdrom or local directory
      attr_accessor :need_umount

      # @return [List<String>] Contains the directories of unfinished product installations
      attr_accessor :unfinished_installations

      # @return [List<String>] List of the product directories to be installed
      #   @instEnvList
      attr_accessor :to_install

      def initialize
	super
	@location_cache = "nfs.server.com/directory/"
	@need_umount    = true
	@product_cont   = 0
	@inst_dir       = "%s/%d" % [ @inst_dir_base, @product_cont ]
	@unfinished_installations = []
	@to_install     = []
	@source_dir     = @mount_point
        while Dir.exists?(@inst_dir)
          if !File.exists?(@inst_dir + "/installationSuccesfullyFinished.dat") && File.exists?(@inst_dir + "/product.data")
            @unfinished_installations << @inst_dir
          end
          @product_cont = @product_cont.next
        end
        @inst_dir = "%s/%d" % [ @inst_dir_base, @product_cont ]
      end
    end
  end
end
