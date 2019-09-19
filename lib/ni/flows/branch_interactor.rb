module Ni::Flows
  class BranchInteractor < Base
    include Ni::Flows::Utils::HandleWait

    attr_accessor :interactor_klass, :action, :condition

    def initialize(top_level_interactor_klass, args, options, &block)
      if options[:when].blank? || !options[:when].is_a?(Proc)
        raise "Can't build brunch without a condition"
      else
        self.condition = options[:when]
      end

      if args.size == 2
        interactor_klass, action = args
      else
        id_or_interactor = args.first
        action = :perform
        
        if id_or_interactor.is_a?(Symbol)          
          interactor_klass = build_anonymous_interactor(top_level_interactor_klass, id_or_interactor, &block)
        else
          interactor_klass = id_or_interactor
        end
      end

      self.interactor_klass, self.action = interactor_klass, action
    end

    def call(context, params={})
      return unless self.condition.call(context)
        
      run(context, params)
    end

    def call_for_wait_continue(context, params={})
      call(context, params)
    end

    def handle_current_wait?(context, name)
      self.condition.call(context) && super
    end

    private    

    def run(context, params={})
      interactor_klass.public_send(action, context, params)
    end

    def build_anonymous_interactor(top_level_interactor_klass, id, &block)
      unless block_given?
        raise "Can't build a branch without a block given"
      end

      klass = Class.new
      klass.include Ni::Main
      klass.unique_id id
      klass.copy_storage_and_metadata_repository(top_level_interactor_klass)

      klass.instance_eval &block

      klass
    end
  end
end
