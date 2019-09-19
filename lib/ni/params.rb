module Ni
  module Params
    extend ActiveSupport::Concern

    class Mapper
      CONFIG_MAP = {
        String => :description,
        Hash   => :options,
        Proc   => :contract,
        Symbol => :method_contract
      }

      def self.perform(args)
        args.each_with_object({}) do |next_arg, acc|
          option = CONFIG_MAP[next_arg.class]

          fail 'unknown argument' unless option.present?

          acc[option] = next_arg
        end
      end
    end

    included do
      def allow_to_read?(action, name)
        receive_contracts = select_contracts_for_action(self.class.receive_contracts, action)
        mutate_contracts  = select_contracts_for_action(self.class.mutate_contracts, action)
        provide_contracts = select_contracts_for_action(self.class.provide_contracts, action)

        return true if receive_contracts.blank? && mutate_contracts.blank? && provide_contracts.blank?

        receive_contracts.keys.include?(name) ||
        mutate_contracts.keys.include?(name)
      end

      def allow_to_write?(action, name)
        receive_contracts = select_contracts_for_action(self.class.receive_contracts, action)
        mutate_contracts  = select_contracts_for_action(self.class.mutate_contracts, action)
        provide_contracts = select_contracts_for_action(self.class.provide_contracts, action)

        return true if receive_contracts.blank? && mutate_contracts.blank? && provide_contracts.blank?

        provide_contracts.keys.include?(name) ||
        mutate_contracts.keys.include?(name)
      end

      protected

      def ensure_received_params(action=DEFAULT_ACTION)
        ensure_contracts self.class.receive_contracts, action
        ensure_contracts self.class.mutate_contracts, action
      end

      def ensure_provided_params(action=DEFAULT_ACTION)
        ensure_contracts self.class.provide_contracts, action
      end

      def ensure_contracts(contracts, action)
        select_contracts_for_action(contracts, action).each do |param, contract|
          value = context.raw_get(param)

          if contract[:contract].present?
            unless contract[:contract].call(value)
              fail "Value of `#{param}` doesn't match to contract"
            end
          end

          if contract[:method_contract].present?
            unless value.respond_to?(contract[:method_contract], true)
              fail "Value of `#{param}` doesn't respond to contract method :#{contract[:method_contract]}"
            end

            unless value.send(contract[:method_contract])
              fail "Value of `#{param}` doesn't match to contract :#{contract[:method_contract]}"
            end
          end
        end
      end

      def select_contracts_for_action(contracts, action)
        (contracts || {}).select do |_, contract|
          contract.dig(:options, :for).blank? || contract.dig(:options, :for) == action
        end
      end
    end

    module ClassMethods
      attr_accessor :receive_contracts, :provide_contracts, :mutate_contracts

      def receive(*args)
        @receive_contracts ||= {}
        name = args.shift
        @receive_contracts[name] = Mapper.perform(args)
      end

      def provide(*args)
        @provide_contracts ||= {}
        name = args.shift
        @provide_contracts[name] = Mapper.perform(args)
      end

      def mutate(*args)
        @mutate_contracts ||= {}
        name = args.shift
        @mutate_contracts[name] = Mapper.perform(args)
      end
    end
  end
end
