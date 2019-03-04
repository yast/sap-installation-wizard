# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "ui/sequence"
require "y2sap/media"
require "y2sap/products"
Yast.import "Wizard"

module Y2Sap
  module Clients
    # Creates the warkflow for the installation
    class Sequence < UI::Sequence
      include Yast::Logger

      SEQUENCE_HASH = {
        START => "read",
        "read" => {
          abort: :abort,
          next:  "read_im"
        },
        "read_im" => {
          abort:   :abort,
          HANA:    "suplementary",
          B1:      "suplementary",
          TREX:    "suplementary",
          SAPINST: "net_weaver"
        },
        "net_weaver" => {
          abort: :abort,
          next:  "suplementary_with_back"
        },

        "suplementary" => {
          abort:  :abort,
          next:   "add_repo"
        },
        "suplementary_with_back" => {
          abort: :abort,
          back:  "net_weaver",
          next:  "add_repo"
        },
        "add_repo" => {
          abort: :abort,
          next:  "nw_installation_mode"
        },
        "nw_installation_mode" => {
          abort:  :abort,
          next:   "nw_product"
        },
        "nw_product" => {
          abort:  :abort,
          next:   "read_parameter"
        },
        "read_parameter" => {
          abort: :abort,
          back:  "suplementary",
          read_im: "read_im",
          next:  "install_sap"
        },
        "install_sap" => {
          abort: :abort,
          next:  "tuning"
        },
        "tuning" => {
          abort: :abort,
          next:  "hana_firewall"
        },
        "hana_firewall" => {
          abort: :abort,
          next:  :next
        }
      }

      def initialize
        textdomain "sap-installation-wizard"
      end

      def run
        log.info("Start the sap-installation-wizard")
        Yast::Wizard.CreateDialog
        Yast::Wizard.SetDesktopTitleAndIcon("sap-installation-wizard")
        super(sequence: SEQUENCE_HASH)
      end

      def read
        @media    = Y2Sap::Media.new
        @products = Y2Sap::Products.new(@media)
        @media.nil? ? :abort : :next
      end

      def read_im
        @media.installation_master
      end

      def net_weaver
        @media.net_weaver
      end

      def suplementary
        @media.suplementary
      end

      def suplementary_with_back
        @media.suplementary
      end

      def nw_installation_mode
        log.info("Start nw_installation_mode")
        @products.nw_installation_mode
      end

      def nw_product
        log.info("Start nw_product")
        @products.nw_product
      end

      def install_sap
        @products.install_sap
      end

      def add_repo
        #TODO
        print "add_repo"
        :next
      end

      def read_parameter
        @products.read_parameter
        :next
      end

      def tuning
        #TODO
        print "tuning"
        :next
      end

      def hana_firewall
        #TODO
        print "hana_firewall"
        :next
      end

    end
  end
end
