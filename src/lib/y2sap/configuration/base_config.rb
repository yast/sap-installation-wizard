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

require "yast"

module Y2Sap
  module Configuration
    class BaseConfig

      # @return [String] The directory where the media will be mounted temporary
      attr_reader :mount_point

      # @return [String] The directory where the media will be copied
      attr_reader :media_dir

      # @return [String] The directory where the sap installation envinroments will be created
      attr_reader :inst_dir_base

      # @return [String] The file containing the base definitions of SAP products
      attr_reader :product_definitions  #@xmlFilePath

      # @return [String] The directory where the partitioning xml files are placed
      attr_reader :partitioning_dir_base #@partXMLPath

      # @return [String] The directory where the autoyast xml are placed
      attr_reader :ay_dir_base #@ayXMLPath

      # @return [String] Path to the product installation script
      attr_accessor :install_script

      # @return [String] The mode of the installation:
      #   * manual  Normal instalation
      #   * auto    Installation without user interraction
      #   * preauto Preparing an auto installation envinroment
      attr_accessor :inst_mode

      # @return [String] URL where the SAP media are provided
      attr_reader :sap_cds_url

      def initialize
        @mount_point   = read_with_default("SOURCEMOUNT","/mnt")
        @media_dir     = read_with_default("MEDIADIR","/data/SAP_CDs")
        @inst_dir_base = read_with_default("INSTDIR","/data/SAP_INST")
        @product_definitions   = read_with_default("MEDIAS_XML","/etc/sap-installation-wizard.xml")
        @partitioning_dir_base = read_with_default("PART_XML_PATH","/usr/share/YaST2/data/y2sap")
        @ay_dir_base           = read_with_default("PRODUCT_XML_PATH","/usr/share/YaST2/data/y2sap")
        @install_script        = read_with_default("SAPINST_SCRIPT","/usr/share/YaST2/data/y2sap")
        @inst_mode             = read_with_default("SAP_AUTO_INSTALL","no") == "yes" ? "auto" : "manual"
        @sap_cds_url           = read_with_default("SAP_EXPORT_CDS","")
      end

      def read_with_default(variable,default)
        value=SCR.Read(path(path(".sysconfig.sap-installation-wizard.".variable))
        return default if value == nil
        return value
      end
    end
  end
end

