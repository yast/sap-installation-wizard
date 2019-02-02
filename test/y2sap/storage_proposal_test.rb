#!/usr/bin/env rspec
# encoding: utf-8
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
require "y2sap/partitioning/storage_proposal"

describe Y2Sap::StorageProposal do
  subject(:proposal) do
    described_class.new(partitioning, device)
  end

  let(:device) { "/dev/vda" }
  let(:partitioning) { { "device" => "/dev/sda" } }
  let(:new_partitioning) { { "device" => device } }
  let(:autoinst_proposal) { double(Y2Storage::AutoinstProposal, propose: true) }
  let(:preprocessor) do
    instance_double(Y2Sap::PartitioningPreprocessor, preprocess: new_partitioning)
  end

  before do
    allow(Y2Sap::PartitioningPreprocessor).to receive(:new).and_return(preprocessor)
    allow(Y2Storage::AutoinstProposal).to receive(:new).and_return(autoinst_proposal)
  end

  describe "#initialize" do
    it "creates an autoinst proposal" do
      expect(autoinst_proposal).to receive(:propose)
      expect(Y2Storage::AutoinstProposal).to receive(:new).with(partitioning: new_partitioning)
      described_class.new(partitioning, device)
    end

    it "preprocesses the given profile" do
      expect(preprocessor).to receive(:preprocess).with(partitioning, device)
      described_class.new(partitioning, device)
    end
  end

  describe "#failed?" do
    before do
      allow(autoinst_proposal).to receive(:failed?).and_return(failed)
    end

    context "when the proposal failed" do
      let(:failed) { true }

      it "return true" do
        expect(proposal.failed?).to eq(true)
      end
    end

    context "when the proposal was successful" do
      let(:failed) { false }

      it "return false" do
        expect(proposal.failed?).to eq(false)
      end
    end
  end
end
