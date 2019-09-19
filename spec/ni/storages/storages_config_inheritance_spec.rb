require 'rails_helper'

RSpec.describe 'Storages config spec' do
  module Scs
    class Level1
      include Ni::Main

      storage Ni::Storages::Default
      metadata_repository Ni::Storages::ActiveRecordMetadataRepository

      def perform
        raise 'Should not be here'
      end
    end

    class Level2 < Level1
    end

    class Level3 < Level2
    end
  end

  it 'should go to second branch and then to first in subranch' do
    expect(Scs::Level3.context_storage_klass).to eq Ni::Storages::Default
    expect(Scs::Level3.metadata_repository_klass).to eq Ni::Storages::ActiveRecordMetadataRepository
  end 
end
