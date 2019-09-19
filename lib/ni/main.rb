module Ni
  module Main  
    extend ActiveSupport::Concern

    include Ni::Params
    include Ni::StoragesConfig
    include Ni::Help

    module ModuleMethods
      def register_unique_interactor(id, interactor_klass)
        @unique_ids_map ||= {}

        # ruby has a strange behaviour here while comparing classes. 
        # Think it's an Rails autoload issue, but should compare the class names
        if @unique_ids_map[id].present? 
          if interactor_klass.name.present? && @unique_ids_map[id].name != interactor_klass.name
            raise "Try to register new interactor with the existing ID: #{id}"        
          end  
        end
        
        @unique_ids_map[id] = interactor_klass
      end  
    end

    extend ModuleMethods


    included do
      attr_accessor :context

      delegate :success?, :valid?, :can_perform_next_step?, :errors, to: :context

      def failure?
        !success?
      end

      def initialize
        self.class.define_actions! if need_to_define_actions?
      end

      def need_to_define_actions?
        self.class.defined_actions.present? &&
        self.class.defined_actions.keys.map(&:first).any? { |name| !respond_to?(name) }
      end

      def returned_values(name)
        keys = self.class.action_by_name(name)&.returned_values.presence ||
          self.select_contracts_for_action(self.class.provide_contracts, name)&.keys

        Array(keys).map { |key| context.raw_get(key) }
      end

      def safe_context(action)
        context.within_interactor self, action do
          ensure_received_params(action)
          result = yield
          ensure_provided_params(action)

          result
        end
      end

      def handle_exceptions(action_exceptions)
        yield

        nil
      rescue Exception => ex
        _, rescue_callback = action_exceptions.find { |(rescue_list, _)| rescue_list.include?(ex.class) }

        rescue_callback ||= begin
          callbacks_array = action_exceptions.find do |(rescue_list, _)|
            rescue_list.any? { |exception_class| ex.class <= exception_class }
          end
          callbacks_array&.last
        end

        raise ex unless rescue_callback.present?

        [rescue_callback, ex]
      end

      def before_action(action_name)
        # Can be defined in ancestors
      end
      
      def after_action(action_name)
        # Can be defined in ancestors
      end 

      def on_success(action_name)
        # Can be defined in ancestors
      end

      def on_cancel(action_name)
        # Can be defined in ancestors
      end
      
      def on_terminate(action_name)
        # Can be defined in ancestors
      end  

      def on_failure(action_name)
        # Can be defined in ancestors
      end

      def on_context_restored(action_name)
        # Can be defined in ancestors
      end

      def on_checking_continue_signal(unit)
        # Can be defined in ancestors
      end

      def on_continue_signal_checked(unit, wait_cheking_result)
        # Can be defined in ancestors
      end
    end

    module ClassMethods
      def unique_id(id=nil)
        @unique_interactor_id = id
        Ni::Main.register_unique_interactor(interactor_id, self)
      end  

      # without specified ID will use class name
      def interactor_id
        @unique_interactor_id || name
      end  

      def interactor_id!
        @unique_interactor_id || raise("The #{self.name} requires an explicit definition of the unique id")
      end

      def action(*args, &block)
        self.defined_actions ||= {}

        name, description = args
        description ||= 'No description'

        ActionChain.new(self, name, description, &block)
      ensure
        unless respond_to?(name)
          define_singleton_method name do |*args, **params|
            context = args.first

            perform_custom(name, context, params)
          end
        end
      end

      attr_accessor :defined_actions

      def perform(*args, **params)
        context = args.first

        perform_custom(:perform, context, params)
      end

      def perform_custom(*args, **params)
        object = self.new

        name, context = args

        system_uid = params.delete(:system_uid)
        wait_completed_for = params.delete(:wait_completed_for)

        context ||= Ni::Context.new(object, name, system_uid)
        context.continue_from!(wait_completed_for) if wait_completed_for.present?
        context.assign_data!(params)
        context.assign_current_interactor!(object)

        object.context = context
        object.public_send(name)

        Ni::Result.new object.context.resultify!, object.returned_values(name)
      end

      def define_actions!
        defined_actions.keys.map(&:first).each { |name| define_action!(name) }
      end

      def define_action!(name)
        raise 'Action not described' unless action_by_name(name).present?

        action_units = action_by_name(name).units
        action_failure_callback = action_by_name(name).failure_callback
        action_exceptions = action_by_name(name).rescues

        define_method name do
          if context.should_be_restored?
            unless self.class.context_storage_klass.present? && self.class.metadata_repository_klass.present?
              raise "Storages was not configured"
            end
            
            self.class.context_storage_klass.new(context, self.class.metadata_repository_klass).fetch  
            on_context_restored(name)
          end

          before_action(name)

          action_units.each do |unit|
            return if context.execution_halted?
            return if context.chain_skipped?
            
            if context.wait_for_execution?
              # Send to other interactor chain
              if unit.respond_to?(:handle_current_wait?) && unit.handle_current_wait?(context, context.continue_from)
                rescue_callback, ex = safe_context name do
                  handle_exceptions action_exceptions do
                    unit.call_for_wait_continue(self.context, wait_completed_for: context.continue_from, system_uid: context.system_uid)                    
                  end                  
                end  
                next unless rescue_callback.present?
              elsif unit.is_a?(Ni::Flows::WaitForCondition)
                
                on_checking_continue_signal(unit)
                wait_cheking_result = unit.wait_or_continue(context.continue_from, context, self.class.metadata_repository_klass)
                on_continue_signal_checked(unit, wait_cheking_result)
                
                case wait_cheking_result
                when Ni::Flows::WaitForCondition::SKIP                    
                  next
                when Ni::Flows::WaitForCondition::WAIT
                  return
                when Ni::Flows::WaitForCondition::COMPLETED
                  context.wait_completed!
                  unit.clear_timer!(context, self.class.metadata_repository_klass)
                  next                   
                end    
              else  
                next
              end    
            end              


            # This can't be replaced with if ... else
            # The wait checking hooks can change the context so need to ensure if block can be performed
            # And from other side the performing block is also able to change context and terminate execution
            if can_perform_next_step?              
              # Previous step could send flow to existing chain
              rescue_callback, ex = safe_context name do
                handle_exceptions action_exceptions do
                  if unit.is_a?(Proc)
                    instance_eval(&unit)
                  elsif unit.is_a?(Symbol)
                    send(unit)
                  elsif unit.is_a?(String)      
                    unit.to_s.split('.').reduce(self) {|memo, name| memo.send(name) }
                  elsif unit.kind_of?(Ni::Flows::Base)
                    unit.call(self.context)
                  elsif unit.kind_of?(Ni::Flows::WaitForCondition)
                    if self.class.context_storage_klass.present? && self.class.metadata_repository_klass.present?
                      self.class.context_storage_klass.new(context, self.class.metadata_repository_klass).store  
                    else
                      raise "WaitFor require a store and metadata repository"
                    end

                    unit.setup_timer!(context, self.class.metadata_repository_klass)
                    context.halt_execution!
                    
                    return
                  end
                end
              end

              if rescue_callback.present?
                instance_exec(ex, &rescue_callback)

                context.failure!
              end
            end

            unless can_perform_next_step?
              instance_eval(&action_failure_callback) if context.failed? && action_failure_callback.present?
              
              {
                :failed?     => :on_failure,
                :canceled?   => :on_cancel,
                :terminated? => :on_terminate
              }.each do |predicate, callback|
                if context.public_send(predicate)                  
                  if unit.respond_to?(callback) && unit.public_send(callback).present?
                    if unit.public_send(callback).is_a?(Proc)
                      instance_exec(&unit.public_send(callback))                      
                    end
                    
                    if unit.public_send(callback).is_a?(Class)
                      unit.public_send(callback).perform(context)
                    end
                  end                    
  
                  self.public_send(callback, name)
                end   
              end                

              after_action(name)
              return
            end
          end

          after_action(name)
          on_success(name)
        end
      end

      def action_by_name(name)
        return nil unless defined_actions.present?

        action = defined_actions.find { |(action_name, _), _| action_name == name }

        Array(action).last
      end

      def units_by_interface(interface)
        defined_actions.values.map(&:units).flatten.select { |u| u.respond_to?(interface) }
      end  
    end
  end
end
