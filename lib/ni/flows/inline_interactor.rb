module Ni::Flows
  class InlineInteractor < Base
    include Ni::Flows::Utils::HandleWait

    attr_accessor :interactor_klass, :action, :on_cancel, :on_failure, :on_terminate

    def initialize(interactor_klass, action, options={})
      self.on_cancel = options[:on_cancel]
      self.on_failure = options[:on_failure]
      self.on_terminate = options[:on_terminate]

      self.interactor_klass, self.action = interactor_klass, action
    end

    def call(context, params={})
      interactor_klass.public_send(action, context, params)
    end  

    def call_for_wait_continue(context, params={})
      call(context, params)
    end
  end
end
