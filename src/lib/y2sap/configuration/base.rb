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

require "yast"
require "fileutils"

module Y2Sap
  module Configuration
    # Class to read and edit thte SLES4SAP base configuration
    class Base
      include Yast
      Yast.import "Misc"
      Yast.import "Arch"

      TMP_PATH = "/var/run/sap-wizard/"

      # @return [String] The architectur
      attr_reader :arch

      # @return [String] The platform
      attr_reader :platform

      # @return [String] The platform architecture in uppercase
      attr_reader :platform_arch

      # @return [String] The directory where the media will be mounted temporary
      attr_reader :mount_point

      # @return [String] The directory where the media will be copied
      attr_reader :media_dir

      # @return [String] The directory where the sap installation envinroments will be created
      attr_reader :inst_dir_base

      # @return [String] The file containing the base definitions of SAP products
      attr_accessor :product_definitions # @xmlFilePath

      # @return [String] The directory where the partitioning xml files are placed
      attr_reader :partitioning_dir_base # @partXMLPath

      # @return [String] The directory where the autoyast xml are placed
      attr_reader :ay_dir_base # @ayXMLPath

      # @return [String] Path to the directory containing the product installation scripts
      attr_accessor :sapinst_path

      # @return [String] The mode of the installation:
      #   * manual  Normal instalation
      #   * auto    Installation without user interraction
      #   * preauto Preparing an auto installation envinroment
      attr_accessor :inst_mode

      # @return [String] URL where the SAP media are provided
      attr_reader :sap_cds_url

      # @return [Hash] the autoinstallation settings
      attr_accessor :sap_media_todo

      def initialize(product_definitions = nil)
        @platform = "LINUX"
        @arch = Yast::Arch.architecture
        @platform_arch = @platform + "_" + @arch
        @platform_arch.upcase!
        @mount_point           = config_read("SOURCEMOUNT", "/mnt")
        @media_dir             = config_read("MEDIADIR", "/data/SAP_CDs")
        @inst_dir_base         = config_read("INSTDIR", "/data/SAP_INST")
        @product_definitions   = config_read(
          "MEDIAS_XML",
          "/usr/share/YaST2/data/y2sap/sap-installation-wizard.xml"
        )
        @partitioning_dir_base = config_read("PART_XML_PATH", "/usr/share/YaST2/data/y2sap")
        @ay_dir_base           = config_read("PRODUCT_XML_PATH", "/usr/share/YaST2/data/y2sap")
        @sapinst_path          = config_read("SAPINST_PATH", "/usr/lib/YaST2/bin/")
        @inst_mode             = config_read("SAP_AUTO_INSTALL", "no") == "yes" ? "auto" : "manual"
        @sap_cds_url           = config_read("SAP_CDS_URL", "")
        @sap_media_todo = {}
        @product_definitions = product_definitions if !product_definitions.nil?
        ::FileUtils.mkdir_p TMP_PATH
      end

    private

      def config_read(path, def_val)
        return Yast::Misc.SysconfigRead(
          Yast::Path.new(".sysconfig.sap-installation-wizard." + path),
          def_val
        )
      end
    end
  end
end
