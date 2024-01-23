#!/usr/bin/env rspec

#
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

require_relative "../spec_helper"
require "y2sap/partitioning/partitioning_preprocessor"

describe Y2Sap::PartitioningPreprocessor do
  LV_BASE = { "create" => true, "filesystem" => :xfs, "format" => true }.freeze

  subject(:preprocessor) { described_class.new }

  let(:device) { "/dev/sda" }
  let(:memory) { Y2Storage::DiskSize.parse("4GB").to_i }

  let(:size_min) { "20GB" }
  let(:size_max) { "50GB" }

  let(:lv_data) do
    LV_BASE.merge("mount" => "/hana/data", "lv_name" => "lv_data",
      "size_min" => size_min, "size_max" => size_max)
  end

  let(:vg_hana) do
    {
      "device"     => "/dev/vg_hana",
      "type"       => :CT_LVM,
      "initialize" => true,
      "partitions" => [
        lv_data,
        LV_BASE.merge("mount" => "swap", "lv_name" => "swap", "filesystem" => :swap)
      ]
    }
  end

  let(:partitioning) { [vg_hana] }

  describe "#preprocess" do
    before do
      allow(Yast::SCR).to receive(:Read).with(Yast::Path.new(".probe.memory"))
        .and_return(["resource" => { "phys_mem" => [{ "range" => memory }] }])
    end

    it "returns an array containing drives definitions" do
      new_partitioning = preprocessor.preprocess(partitioning, device)
      expect(new_partitioning).to be_a(Array)
      expect(new_partitioning.first).to include("device" => "/dev/vg_hana")
    end

    it "includes a physical volume for each volume group" do
      new_partitioning = preprocessor.preprocess(partitioning, device)
      expect(new_partitioning).to contain_exactly(
        a_hash_including("device" => "/dev/vg_hana", "type" => :CT_LVM),
        a_hash_including("device" => device, "use" => "free", "type" => :CT_DISK)
      )
    end

    context "when size is specified as RAM * multiplier" do
      let(:size_min) { "RAM * 0.5" }
      let(:size_max) { nil }

      it "sets the size according to the RAM size" do
        new_partitioning = preprocessor.preprocess(partitioning, device)
        lv = new_partitioning.first["partitions"].first
        expect(lv["size"]).to eq("2000000000")
      end
    end

    context "when max size is smaller than min size" do
      let(:size_min) { "4G" }
      let(:size_max) { "1G" }

      it "sets the size according to the max size" do
        new_partitioning = preprocessor.preprocess(partitioning, device)
        lv = new_partitioning.first["partitions"].first
        expect(lv["size"]).to eq("1000000000")
      end
    end

    context "when min size is smaller than max size" do
      let(:size_min) { "1G" }
      let(:size_max) { "4G" }

      it "sets the size according to the min size" do
        new_partitioning = preprocessor.preprocess(partitioning, device)
        lv = new_partitioning.first["partitions"].first
        expect(lv["size"]).to eq("1000000000")
      end
    end
  end
end
