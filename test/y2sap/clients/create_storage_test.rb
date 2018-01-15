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

require_relative "../../spec_helper"
require "sap/clients/create_storage"

describe Y2Sap::Clients::CreateStorage do
  subject(:client) { described_class.new }

  let(:devicegraph) { instance_double(Y2Storage::Devicegraph, disks: disks) }
  let(:storage) do
    instance_double(
      Y2Storage::StorageManager,
      activate: true,
      probed?:  true,
      probed:   devicegraph,
      commit:   nil
    )
  end

  let(:eligible_disk) do
    instance_double(Y2Storage::Disk, name: "/dev/sda", free_spaces: [double("space")])
  end
  let(:other_disk) do
    instance_double(Y2Storage::Disk, name: "/dev/sdb", free_spaces: [])
  end

  let(:disks) { [eligible_disk, other_disk] }
  let(:failed?) { false }
  let(:proposal) { instance_double(Y2Sap::StorageProposal, failed?: failed?, save: nil) }

  describe "#main" do
    let(:args) { [File.join(DATA_PATH, "hana_partitioning.xml")] }

    before do
      allow(Yast::WFM).to receive(:Args).and_return(args)
      allow(Y2Storage::StorageManager).to receive(:instance).and_return(storage)
      allow(Y2Sap::StorageProposal).to receive(:new).and_return(proposal)
    end

    it "creates a proposal" do
      expect(Y2Sap::StorageProposal).to receive(:new).with(Array, eligible_disk.name)
        .and_return(proposal)
      expect(proposal).to receive(:save)
      expect(storage).to receive(:commit)
      client.main
    end

    it "returns :next" do
      expect(client.main).to eq(:next)
    end

    context "when the proposal fails" do
      let(:failed?) { true }

      it "returns :abort" do
        allow(Yast::Popup).to receive(:Error)
        expect(client.main).to eq(:abort)
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        client.main
      end

      it "does not save or commit anything" do
        expect(proposal).to_not receive(:save)
        expect(storage).to_not receive(:commit)
        client.main
      end
    end

    context "when no file is specified" do
      let(:args) { [] }

      it "returns :abort" do
        allow(Yast::Popup).to receive(:Error)
        expect(client.main).to eq(:abort)
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        client.main
      end
    end

    context "when the profile does not exist" do
      let(:args) { ["some-profile.xml"] }

      it "returns :abort" do
        allow(Yast::Popup).to receive(:Error)
        expect(client.main).to eq(:abort)
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        client.main
      end
    end

    context "when the profile is not valid" do
      let(:args) { ["test/spec_helper.rb"] }

      it "returns :abort" do
        allow(Yast::Popup).to receive(:Error)
        expect(client.main).to eq(:abort)
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        client.main
      end
    end

    context "when no suitable disks are found" do
      let(:disks) { [other_disk] }

      it "returns :abort" do
        allow(Yast::Popup).to receive(:Error)
        expect(client.main).to eq(:abort)
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        client.main
      end
    end

    context "when more than one suitable disk is found" do
      let(:disks) { [eligible_disk, eligible_disk, other_disk] }
      let(:disk_selector) do
        instance_double(Y2Autoinstallation::Dialogs::DiskSelector, run: eligible_disk.name)
      end

      before do
        allow(Y2Autoinstallation::Dialogs::DiskSelector).to receive(:new)
          .and_return(disk_selector)
      end

      it "asks the user about which one to use" do
        expect(disk_selector).to receive(:run).and_return(eligible_disk.name)
        client.main
      end

      it "only considers disks with free space" do
        expect(Y2Autoinstallation::Dialogs::DiskSelector).to receive(:new)
          .with(blacklist: [other_disk.name]).and_return(disk_selector)
        client.main
      end

      context "when the user does not select any disk" do
        before do
          allow(disk_selector).to receive(:run).and_return(nil)
        end

        it "does not tries to create a proposal" do
          expect(Y2Sap::StorageProposal).to_not receive(:new)
          client.main
        end
      end
    end
  end
end
