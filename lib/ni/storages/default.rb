module Ni
  module Storages
    class Default
      METADATA_REPOSITORY_KEY = 'store_state'

      def initialize(context, metadata_repository_klass)
        @context, @metadata_repository_klass = context, metadata_repository_klass

        @storages_map = {}

        setup_custom_storages

        if defined?(ActiveRecord) && !skip_default_storages?
          register_storage :active_record_record, {
            match: ActiveRecord::Base,
            store: -> (record) { record.save!; [record.class.name, record.id] },
            fetch: -> (data)   { data.first.constantize.find(data.last) }
          }

          register_storage :active_record_collection, {
            match: -> (value) do 
              value.respond_to?(:each) && 
              value.all? { |element| element.is_a?(ActiveRecord::Base) } &&
              value.all? { |element| element.class == value.first.class }
            end,
            store: -> (records) do
              records.each(&:save!)
              [records.first.class.name] + records.map(&:id)
            end,
            fetch: -> (data) do
              klass = data.shift.constantize
              klass.where(id: data)
            end    
          }
        end

        unless skip_default_storages?
          register_storage :true_value, {
            match: TrueClass,
            store: -> (value)  { nil },
            fetch: -> (data)   { true }
          }

          register_storage :false_value, {
            match: FalseClass,
            store: -> (value)  { nil },
            fetch: -> (data)   { false }
          }

          register_storage :string_value, {
            match: String,
            store: -> (value)  { value },
            fetch: -> (data)   { data  }
          }

          register_storage :integer_value, {
            match: Integer,
            store: -> (value)  { value },
            fetch: -> (data)   { data.to_i }
          }

          register_storage :float_value, {
            match: Float,
            store: -> (value)  { value },
            fetch: -> (data)   { data.to_f }
          }

          register_storage :symbol_value, {
            match: Symbol,
            store: -> (value)  { value },
            fetch: -> (data)   { data.to_sym }
          }

          register_storage :nil_value, {
            match: NilClass,
            store: -> (value)  { nil },
            fetch: -> (data)   { nil }
          }
        end
      end

      def store
        fetch_data = {}

        @context.each do |name, value|
          known_storage, config = @storages_map.find do |storage_name, cfg|
            match = cfg[:match]

            (match.is_a?(Class)  && value.is_a?(match)) ||
            (match.is_a?(String) && value.is_a?(match.constantize)) ||
            (match.is_a?(Proc)   && match.call(value))
          end

          if respond_to?(:"store_#{name}")
            fetch_data[name] = { known_storage: nil, data: public_send(:"store_#{name}", value) }
          elsif known_storage.present?
            known_logic = config[:store]

            if known_logic.is_a?(Proc)  
              fetch_data[name] = { known_storage: known_storage, data: known_logic.call(value) }
            else
              raise "Storage logic type is not supported"
            end    
          else
            raise "Logic for storing #{name} was not defined"  
          end
        end

        @metadata_repository_klass.store(@context.system_uid, METADATA_REPOSITORY_KEY, fetch_data)
      end

      def fetch
        fetch_data = @metadata_repository_klass.fetch(@context.system_uid, METADATA_REPOSITORY_KEY)

        fetch_data.each do |name, data|
          next if @context.has_key?(name) # do not restore an existing value. E.g. it can be provided on process launch

          if respond_to?(:"store_#{name}")
            @context.raw_set(name, public_send(:"fetch_#{name}", data[:data]))
          elsif data[:known_storage].present?
            if @storages_map[data[:known_storage].to_sym].present?
              @context.raw_set(name, @storages_map[data[:known_storage].to_sym][:fetch].call(data[:data]))
            else
              raise "Storage is not known"
            end    
          else
            raise "Doesn't know how to fetch #{name}"
          end
        end  
      end

      private

      def skip_default_storages?
        false
      end

      def setup_custom_storages
        # can be defined for custom storages
      end

      def register_storage(name, config)
        @storages_map[name] ||= config
      end  
    end
  end
end