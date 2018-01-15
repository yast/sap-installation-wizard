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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "sap/storage_proposal"
require "y2storage"
require "autoinstall/dialogs/disk_selector"

Yast.import "XML"
Yast.import "Wizard"
Yast.import "WFM"
Yast.import "Popup"

module Y2Sap
  module Clients
    # Client to create SAP storage
    class CreateStorage
      include Yast::I18n
      include Yast::Logger

      # Client entry point
      def main
        textdomain "sap"

        Yast::Wizard.CreateDialog

        partitioning = read_partitioning
        if partitioning.nil?
          Yast::Popup.Error("A path to a valid profile is required")
          return :abort
        end

        disk = select_disk

        if disk.nil?
          Yast::Popup.Error("No suitable disk was found")
          return :abort
        end

        return :abort unless commit(partitioning, disk)
        Yast::Wizard.CloseDialog

        :next
      end

    private

      # Save changes to hard disk
      def commit(partitioning, disk)
        proposal = Y2Sap::StorageProposal.new(partitioning, disk)
        if proposal.failed?
          Yast::Popup.Error("Unable to create needed devices")
          return false
        end
        proposal.save
        Y2Storage::StorageManager.instance.commit
        true
      end

      # Read profile from the file given as argument to the client
      #
      # @return [Hash] Profile content
      def read_partitioning
        filename = Yast::WFM.Args.first
        return nil if filename.nil? || !File.exist?(filename)

        profile = Yast::XML.XMLToYCPFile(filename)
        profile && profile["partitioning"]
      end

      # Select a disk with to use
      #
      # If there are more than 1 disk with free space, it will ask the user to select one.
      # FIXME: maybe we should move the disk selection to the preprocessor so you can choose
      # one disk for each volume group.
      #
      # @return [String] Device name
      def select_disk
        return eligible_disks.first unless eligible_disks.size > 1
        blacklist = devicegraph.disks.map(&:name) - eligible_disks
        Y2Autoinstallation::Dialogs::DiskSelector.new(blacklist: blacklist).run
      end

      # Return a list of eligible disks
      #
      # These disks have some free space.
      #
      # @return [Array<String>]
      def eligible_disks
        return @eligible_disks if @eligible_disks
        disks_with_space = devicegraph.disks.reject { |d| d.free_spaces.empty? }
        @eligible_disks = disks_with_space.map(&:name)
      end

      # Return the probed devicegraph
      #
      # This method probes the storage layer if needed.
      #
      # @return [Y2Storage::Devicegraph]
      def devicegraph
        return storage.probed if storage.probed?
        storage.activate
        storage.probe
        storage.probed
      end

      # Convenience method to get the current storage manager instance
      #
      # @return [Y2Storage::StorageManager]
      def storage
        Y2Storage::StorageManager.instance
      end
    end
  end
end
