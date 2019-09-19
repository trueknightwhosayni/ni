module Ni
  class Context
    class Errors
      include Enumerable

      delegate :each, :empty?, :present?, :blank?, to: '@errors'

      def initialize
        @errors = {}
      end

      def add(key, message)
        @errors[key] ||= []
        @errors[key] << message
      end

      def []=(key, message)
        @errors[key] ||= []
        @errors[key] << message
      end

      def full_messages
        @errors.values.flatten
      end

      def to_h
        @errors
      end

      def to_json
        to_h.to_json
      end
    end

    attr_accessor :current_interactor, :current_action, :errors
    attr_accessor :as_result, :system_uid, :continue_from, :external_system_uid
    attr_accessor :halt_execution, :skip_the_rest_chain

    delegate :each, :slice, to: '@data'

    def initialize(interactor, action, system_uid = nil)
      self.external_system_uid = system_uid
      self.system_uid = system_uid || SecureRandom.hex(15)
      self.current_interactor = interactor
      self.current_action = action
      self.errors = Errors.new
      self.as_result = false
      @data = {}
      @success = true
      @terminated = false
    end

    def success?
      @success && valid?
    end 

    def failed?
      !@success || !valid?
    end

    def canceled?
      !@success && valid?
    end

    def terminated?
      @terminated
    end

    def failure!
      @success = false
    end

    def cancel!
      @success = false
    end

    def can_perform_next_step?
      success? && !terminated?
    end

    def success!
      @terminated = true
    end

    def terminate!
      @success = false
      @terminated = true
    end  

    def assign_data!(params)
      @data.merge!(params)
    end

    def assign_current_interactor!(interactor)
      self.current_interactor = interactor
    end

    def continue_from!(name_or_interactor)
      name = name_or_interactor.is_a?(Class) ? name_or_interactor.interactor_id! : name_or_interactor
      self.continue_from = name
    end  

    def halt_execution!
      self.halt_execution = true
    end

    def execution_halted?
      halt_execution.present?
    end

    def skip_the_rest_chain!
      self.skip_the_rest_chain = true
    end

    def chain_skipped?
      skip_the_rest_chain.present?
    ensure
      # I now it's a bad Idea to mutate state in predicates but this operation should be atomic
      self.skip_the_rest_chain = false 
    end

    def wait_completed!
      self.continue_from = nil
    end

    def wait_for_execution?
      continue_from.present?
    end

    def should_be_restored?
      wait_for_execution? || self.external_system_uid.present?
    end

    def resultify!
      self.as_result = true

      self
    end

    def within_interactor(interactor, action)
      stored_interactor = self.current_interactor
      stored_action = self.current_action

      self.current_interactor = interactor
      self.current_action = action

      result = yield

      self.current_interactor = stored_interactor
      self.current_action = stored_action

      result
    end

    def [](name)
      unless allow_to_read?(name)
        raise "The `#{name}` is not allowed to read"
      end

      raw_get(name)
    end

    def []=(name, value)
      unless allow_to_write?(name)
        raise "The `#{name}` is not allowed to write"
      end

      raw_set(name, value)
    end

    # raw_get was defined only for internal purposes only. Please do not use it in your code
    def raw_get(name)
      @data[name.to_sym]
    end

    # raw_set was defined only for internal purposes only. Please do not use it in your code
    def raw_set(name, value)
      @data[name.to_sym] = value
    end

    def respond_to?(name, include_private=false)
      super || has_key?(name)
    end

    def has_key?(name)
      @data.has_key?(name.to_sym)
    end

    def valid?
      errors.empty?
    end

    def invalid?
      !valid?
    end

    def fetch(*args)
      args.map { |name| self[name] }
    end

    def allow_to_read?(name)
      as_result || self.current_interactor.allow_to_read?(self.current_action, name)
    end

    def allow_to_write?(name)
      as_result || self.current_interactor.allow_to_write?(self.current_action, name)
    end

    def method_missing(name, *args, &block)
      if name.to_s.ends_with?('=')
        self[name[0..-2].to_sym] = args.first
      else
        self[name]
      end
    end
  end
end
