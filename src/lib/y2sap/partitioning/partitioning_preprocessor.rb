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

require "yast"
require "y2storage"

module Y2Sap
  # This class takes care of converting a SAP partitioning profile into a valid
  # AutoYaST one.
  #
  # It takes care of:
  #
  # * Preprocessing partition sizes.
  # * Adding a LVM physical volume for each defined volume group.
  class PartitioningPreprocessor
    include Yast
    include Yast::Logger

    # Preprocesses the partitioning section
    #
    # It returns a new object so the original section is not modified.
    #
    # @param drives [Array<Hash>] List of drives according to an AutoYaST
    #   +partitioning+ section.
    def preprocess(drives, device)
      return if drives.nil?
      new_drives = deep_copy(drives)
      adjust_lv_sizes(new_drives)
      add_pvs(new_drives, device)
    end

  private

    # Adjust logical volumes sizes
    #
    # Loop through all the logical volumes adjusting their size.
    #
    # @param drives [Array<Hash>] List of drives according to an AutoYaST
    #   +partitioning+ section.
    #
    # @see #adjust_lv_size
    def adjust_lv_sizes(drives)
      vgs(drives).each do |vg|
        vg["partitions"].each { |l| adjust_partition_size(l) }
      end
    end

    # Add a new LVM physical volume
    #
    # @param drives [Array<Hash>] List of drives according to an AutoYaST
    #   +partitioning+ section.
    # @param device [String] Device to use for physical volumes
    def add_pvs(drives, device)
      pvs = vgs(drives).map { |n| pv_for_vg(n, device) }
      drives.concat(pvs)
    end

    # Return volume groups defined in the profile
    #
    # @param drives [Array<Hash>] List of drives according to an AutoYaST
    #   +partitioning+ section.
    # @return [Array<Hash>]
    def vgs(drives)
      drives.select { |drive| drive["type"] == :CT_LVM }
    end

    # Build a LVM physical volume for a volume group
    #
    # @param drives [Array<Hash>] List of drives according to an AutoYaST
    #   +partitioning+ section.
    # @param device [String] Device to use for physical volumes
    def pv_for_vg(vg, device)
      {
        "device"     => device,
        "use"        => "free",
        "type"       => :CT_DISK,
        "partitions" => [
          "lvm_group"    => File.basename(vg["device"]),
          "size"         => "max",
          "create"       => true,
          "partition_id" => 142
        ]
      }
    end

    # Adjust partition size
    #
    # Parses size_min and size_max attributes and sets the smallest one
    # as the partition size.
    #
    # @param partition [Hash] Partition definition from the profile
    #
    # @see parse_size
    def adjust_partition_size(partition)
      log.info("adjust_partition_size called for #{partition}")
      size_min = parse_size(partition["size_min"])
      size_max = parse_size(partition["size_max"])
      begin
        size = parse_size(partition["size"])
      rescue TypeError
        # <size> contains non size values like 'max' or 'auto'
        return
      end
      size_min = [size_min, size].compact.max
      size = [size_min, size_max].compact.min
      partition["size"] = size.to_i.to_s if size
    end

    # Parse partition size
    #
    # This method implements special 'RAM * x' syntax parsing. It will
    # fallback to default disk size parse if another syntax is used.
    #
    # Non size values, like 'max' or 'auto', are not supported.
    #
    # @param size [String] Size definition
    # @return [DiskSize]
    def parse_size(size)
      return nil if size.nil? || size.empty?

      # RAM * x
      if size.include?("*")
        multiplier = size.split("*").last.strip.to_f
        return Y2Storage::DiskSize.new(multiplier * ram)
      end

      # fallback
      Y2Storage::DiskSize.parse(size.to_s)
    end

    # Determine the amount of memory present in the system
    #
    # @return [Integer] System memory in bytes
    def ram
      probe = Yast::SCR.Read(Yast::Path.new(".probe.memory"))
      return 0 if probe.nil?
      memory = probe.first["resource"]
      memory["phys_mem"][0]["range"]
    end
  end
end
