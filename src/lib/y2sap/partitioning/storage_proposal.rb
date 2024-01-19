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

require "y2storage"
require "y2sap/partitioning/partitioning_preprocessor"

module Y2Sap
  # Represent an AutoYaST partitioning proposal
  #
  # Given a SAP partitioning profile and a device name, it proposes a partitioning proposal
  # for AutoYaST. This class can be considered and equivalent to
  # {Y2Autoinstallation::StorageProposal} which is used in AutoYaST.
  #
  # The procedure works as follow:
  #
  # * Preprocess the SAP partitioning profile ({Y2Sap::PartitioningPreprocessor})
  # * Create the partitioning proposal ({Y2Storage::AutoinstProposal})
  #
  # @see https://github.com/yast/yast-autoinstallation/blob/6a3d0bba0322c405a2e5c9bbe14f44d0feed4d97/src/lib/autoinstall/storage_proposal.rb
  # @see Y2Sap::PartitioningPreprocessor
  # @see https://github.com/yast/yast-storage-ng/blob/3fcd97e9e2481b8b91c0b58fdca9345275beca49/src/lib/y2storage/autoinst_proposal.rb
  class StorageProposal
    include Yast::Logger

    extend Forwardable

    def_delegators :@proposal, :issues_list, :failed?

    # @return [Y2Storage::AutoinstProposal] Y2Storage proposal instance
    attr_reader :proposal

    # Constructor
    #
    # @param partitioning [Array<Hash>] Partitioning section from the AutoYaST profile
    # @param device       [String]      Device to create physical volumes
    #
    # @see https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning
    def initialize(partitioning, device)
      build_proposal(partitioning, device)
    end

    # Save the proposal
    def save
      Y2Storage::StorageManager.instance.proposal = proposal
    end

    # A proposal is failed when it has not devices after being proposed
    # @see Y2Storage::Proposal::Base#failed?
    #
    # @return [Boolean] true if proposed and has no devices; false otherwise
    def failed?
      proposal.failed?
    end

  private

    # Initialize the partition proposal
    #
    # * It relies in the default AutoYaST proposal ({Y2Storage::AutoinstProposal})
    #
    # @return [Y2Storage::AutoinstProposal] Proposal instance
    def build_proposal(partitioning, device)
      adapted_partitioning = Y2Sap::PartitioningPreprocessor.new.preprocess(partitioning, device)
      log.info "Building a proposal with: #{adapted_partitioning.inspect}"
      @proposal = Y2Storage::AutoinstProposal.new(partitioning: adapted_partitioning)
      @proposal.propose
    end
  end
end
