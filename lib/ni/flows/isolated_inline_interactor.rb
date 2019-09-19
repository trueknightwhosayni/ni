module Ni::Flows
  class IsolatedInlineInteractor < Base
    attr_accessor :interactor_klass, :action, :receive_list, :provide_list

    def initialize(interactor_klass, action, options={})
      self.interactor_klass, self.action = interactor_klass, action
      self.receive_list, self.provide_list = Array(options[:receive]), Array(options[:provide])
    end

    def call(context)
      isolated_context = Ni::Context.new(nil, action)
      isolated_context.assign_data!(context.slice(*receive_list))

      result = interactor_klass.public_send(action, isolated_context)

      provide_list.each do |param_name|
        context[param_name] = result.context[param_name]
      end
    end
  end
end
