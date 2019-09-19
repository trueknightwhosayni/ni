module Ni
  class ActionChain
    attr_accessor :name, :description, :received_values, :returned_values, :units, :failure_callback, :rescues

    def initialize(klass, name, description, &block)
      @interactor_klass = klass
      @name = name, @description = description
      @units = block_given? ? [block.to_proc] : []
      @failure_callback = nil
      @rescues = []
      @returned_values = []

      self
    ensure
      update_chain
    end

    # Params methods

    def receive(*args)
      @received_values = args

      self
    ensure
      update_chain
    end

    def provide(*args)
      @returned_values = args

      self
    ensure
      update_chain
    end

    # Flow methods

    def then(*args, **options, &block)
      if block_given?
        @units << block.to_proc
      else
        @units << chain_builder(args, options)
      end

      self
    ensure
      update_chain
    end

    def isolate(*args, **options, &block)
      if block_given?
        raise 'Not Implemented yet'
      else
        first, last = args
        @units << Ni::Flows::IsolatedInlineInteractor.new(first, (last || :perform), options)
      end

      self
    ensure
      update_chain
    end

    def failure(&block)
      @failure_callback = block.to_proc

      self
    ensure
      update_chain
    end

    def rescue_from(*args, &block)
      args = [Exception] if args.empty?

      @rescues << [args, block.to_proc]

      self
    ensure
      update_chain
    end

    def wait_for(condition, options={})
      @units << Ni::Flows::WaitForCondition.new(condition, @interactor_klass, options)

      self
    ensure
      update_chain  
    end  

    def branch(*args, **options, &block)
      @units << Ni::Flows::BranchInteractor.new(@interactor_klass, args, options, &block)

      self
    ensure
      update_chain
    end

    def terminate!
      @units << "context.terminate!"
    ensure  
      update_chain
    end

    def cancel!
      @units << "context.cancel!"
    ensure  
      update_chain
    end

    def failure!
      @units << "context.failure!"
    ensure  
      update_chain
    end

    def success!
      @units << "context.success!"
    ensure  
      update_chain
    end

    private

    def chain_builder(args, options)
      first, last = args

      case first
      when Symbol, String
        first
      when Class
        Ni::Flows::InlineInteractor.new(first, (last || :perform), options)
      else
        raise 'Invalid chain options'
      end
    end

    def update_chain
      @interactor_klass.defined_actions[name] = self
    end
  end
end
