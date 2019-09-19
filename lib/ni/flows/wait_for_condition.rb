module Ni::Flows
  class WaitForCondition
    SKIP = :skip
    WAIT = :wait
    COMPLETED = :completed

    METADATA_REPOSITORY_KEY = 'multiple_wait_for'

    attr_accessor :condition, :timer, :wait_id

    def initialize(condition, interactor_klass, options={})
      self.timer = options[:timer]

      condition = condition.interactor_id! if condition.is_a?(Class)

      self.condition = condition
    end

    def waited_for_name?(name)
      case condition
      when Symbol # wait_for(:some_unique_name)
        self.condition == name             
      when Class #wait_for(OtherInteractor)
        self.condition.interactor_id! == name        
      when Hash  #wait_for(:main_key => [:name, SomeClass, [:name, -> (ctx) { ctx.a == 1 }]])
        self.condition.values
          .flatten
          .select { |item| item.is_a?(Symbol) || item.is_a?(Class) }
          .map { |item| item.is_a?(Class) ? item.interactor_id! : item }
          .include?(name) 
      else 
        raise "Wrong WaitFor options"  
      end 
    end

    def wait_or_continue(check, context, metadata_repository_klass)
      if condition.is_a?(Symbol)
        single_condition(check)
      elsif condition.is_a?(Hash)
        multiple_condition(check, context, metadata_repository_klass)
      else
        raise "Condition format doesn't recognized"
      end 
    end  

    def setup_timer!(context, metadata_repository_klass)
      return unless self.timer.present?

      datetime_proc, timer_klass, timer_action = self.timer
      datetime = datetime_proc.call
      timer_action ||= :perform

      unique_timer_id = "#{self.wait_id}-#{context.system_uid}"

      metadata_repository_klass.setup_timer!(unique_timer_id, datetime, timer_klass.name, timer_action.to_s, contex.system_uid)
    end

    def clear_timer!(context, metadata_repository_klass)
      return unless self.timer.present?

      unique_timer_id = "#{self.wait_id}-#{context.system_uid}"
      
      metadata_repository_klass.clear_timer!(unique_timer_id)
    end

    private

    def single_condition(check)
      condition == check ? COMPLETED : SKIP
    end
    
    def multiple_condition(check, context, metadata_repository)
      unless metadata_repository.present?
        raise "Multiple waits expects the metadata repository definition"
      end  

      global_name = condition.keys.first
      conditions_list = condition.values.first

      conditions_names = conditions_list.flatten.select { |name| name.is_a?(Symbol) }

      unless conditions_names.include?(check)
        return SKIP
      end

      passed_cheks = []

      metadata = metadata_repository.fetch(context.system_uid, METADATA_REPOSITORY_KEY) 
      if metadata.present?
        passed_cheks += metadata.map(&:to_sym)
      end
      
      conditions_list.each do |checked_condition|
        if checked_condition.is_a?(Symbol)
          if checked_condition == check
            passed_cheks << check
            break
          else
            next
          end    
        elsif checked_condition.is_a?(Array) && checked_condition.first.is_a?(Symbol) && checked_condition.last.is_a?(Proc)
          name, callback = checked_condition

          if name == check
            passed_cheks << check if context.current_interactor.instance_exec(context, &callback)            
            break
          else
            next  
          end  
        else
          raise "Multiple waits can contain only symbols or arrays with symbol and proc"
        end      
      end

      unless passed_cheks.present?
        return WAIT
      end

      metadata_repository.store(context.system_uid, METADATA_REPOSITORY_KEY, passed_cheks) 

      if (conditions_names - passed_cheks).empty?
        COMPLETED
      else
        WAIT  
      end  
    end  
  end
end
