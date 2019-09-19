require 'rails_helper'

RSpec.describe 'Default context storage' do
  module Dcs
    class DummyInteractor
      include Ni::Main
    end
  end  
  
  def create_user
    User.create!(email: "#{SecureRandom.hex(12)}@test.com", password: '111111')
  end

  let!(:inital_context)   { Ni::Context.new(Dcs::DummyInteractor, :perform) }
  let!(:restored_context) { Ni::Context.new(Dcs::DummyInteractor, :perform, inital_context.system_uid) }

  let(:storage_klass)  { Ni::Storages::Default }
  let(:metadata_klass) { Ni::Storages::ActiveRecordMetadataRepository }

  describe 'when single active record' do
    let!(:user) { create_user }

    before { inital_context.raw_set(:user, user) }
    before { inital_context.raw_set(:true_value, true) }
    before { inital_context.raw_set(:false_value, false) }
    before { inital_context.raw_set(:string_value, "String") }
    before { inital_context.raw_set(:integer_value, 10) }
    before { inital_context.raw_set(:float_value, 14.34) }
    before { inital_context.raw_set(:symbol_value, :user) }
    before { inital_context.raw_set(:nil_value, nil) }

    let!(:storager) { storage_klass.new(inital_context, metadata_klass) }
    let!(:fetcher)  { storage_klass.new(restored_context, metadata_klass) }

    it 'should store and fetch user' do
      storager.store

      expect(restored_context.raw_get(:user)).to eq(nil)
      
      fetcher.fetch

      expect(restored_context.raw_get(:user)).to eq(user)
      expect(restored_context.raw_get(:true_value)).to eq(true)
      expect(restored_context.raw_get(:false_value)).to eq(false)
      expect(restored_context.raw_get(:string_value)).to eq("String")
      expect(restored_context.raw_get(:integer_value)).to eq(10)
      expect(restored_context.raw_get(:float_value)).to eq(14.34)
      expect(restored_context.raw_get(:symbol_value)).to eq(:user)
      expect(restored_context.raw_get(:nil_value)).to eq(nil)
    end  
  end 

  describe 'when active record collection' do
    let!(:user_1) { create_user }
    let!(:user_2) { create_user }
    let!(:user_3) { create_user }

    before { inital_context.raw_set(:users, User.where(id: [user_1, user_2].map(&:id))) }

    let!(:storager) { storage_klass.new(inital_context, metadata_klass) }
    let!(:fetcher)  { storage_klass.new(restored_context, metadata_klass) }

    it 'should store and fetch user' do
      storager.store

      expect(restored_context.raw_get(:users)).to eq(nil)
      
      fetcher.fetch

      expect(restored_context.raw_get(:users)).to eq([user_1, user_2])
    end
  end  

  describe 'when setup custom storage' do
    class DummyClass1
      def id
        1
      end
      
      def data
        'data 1'
      end
    end

    class DummyClass2
      def id
        2
      end
      
      def data
        'data 2'
      end
    end

    class MyStorage < Ni::Storages::Default
      def setup_custom_storages
        register_storage :dummy_1, {
          match: DummyClass1,
          store: -> (value) { [DummyClass1.name, value.id] },
          fetch: -> (data)   { data.first.constantize.new }
        }
        register_storage :dummy_2, {
          match: 'DummyClass2',
          store: -> (value) { [DummyClass2.name, value.id] },
          fetch: -> (data)   { data.first.constantize.new }
        }
        register_storage :dummy_3, {
          match: -> (value) { value == '1' },
          store: -> (value) { '1' },
          fetch: -> (data)   { '1' }
        }
      end
    end

    let(:storage_klass)  { MyStorage }

    before { inital_context.raw_set(:a, DummyClass1.new) }
    before { inital_context.raw_set(:b, DummyClass2.new) }
    before { inital_context.raw_set(:c, '1') }
    before { inital_context.raw_set(:d, '1') }

    let!(:storager) { storage_klass.new(inital_context, metadata_klass) }
    let!(:fetcher)  { storage_klass.new(restored_context, metadata_klass) }

    it 'should store and fetch custom data' do
      storager.store

      expect(restored_context.raw_get(:a)).to eq(nil)
      expect(restored_context.raw_get(:b)).to eq(nil)
      expect(restored_context.raw_get(:c)).to eq(nil)
      
      restored_context.raw_set(:d, 'previously_initiated')

      fetcher.fetch

      expect(restored_context.raw_get(:a).data).to eq(DummyClass1.new.data)
      expect(restored_context.raw_get(:b).data).to eq(DummyClass2.new.data)
      expect(restored_context.raw_get(:c)).to eq('1')
      expect(restored_context.raw_get(:d)).to eq('previously_initiated')
    end
  end

  describe 'when defined by a method' do
    class MyStorage2 < Ni::Storages::Default
      def skip_default_storages?
        true
      end

      def store_user(record)
        record.save!; [record.class.name, record.id]
      end
      
      def fetch_user(data)
        data.first.constantize.find(data.last)
      end  
    end

    let(:storage_klass)  { MyStorage2 }

    let!(:user) { create_user }

    before { inital_context.raw_set(:user, user) }

    let!(:storager) { storage_klass.new(inital_context, metadata_klass) }
    let!(:fetcher)  { storage_klass.new(restored_context, metadata_klass) }

    it 'should store and fetch user' do
      expect(storager.instance_variable_get(:@storages_map)).to eq({})
      expect(fetcher.instance_variable_get(:@storages_map)).to eq({})

      storager.store

      expect(restored_context.raw_get(:user)).to eq(nil)
      
      fetcher.fetch

      expect(restored_context.raw_get(:user)).to eq(user)
    end
  end  

  describe 'when something goes wrong', pending: "Write it later" do
    context 'when a store attempt' do
      context 'when no logic' do
      end
      
      context 'when storage definition is wrong' do
      end
    end  
    
    context 'when a fetch attempt' do
      context 'when no logic' do
      end
      
      context 'when storage is missing' do
      end
    end
  end   
end