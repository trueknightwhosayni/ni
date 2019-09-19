require 'rails_helper'

RSpec.describe 'Callbacks interactor spec' do
  module Cis
    class Interactor
      include Ni::Main

      mutate :param_1
      mutate :param_2
      mutate :param_3

      def before_action(name)
        if name == :perform
          context.param_1 = 'perform_1'
        else
          context.param_1 = 'custom_perform_1'
        end    
      end
      
      def after_action(name)
        if name == :perform
          context.param_3 = 'perform_3'
        else
          context.param_3 = 'custom_perform_3'
        end    
      end  

      action :perform do
        context.param_2 = 'perform_2'
      end
      .provide(:param_1, :param_2, :param_3)

      action :custom_perform do
        context.param_2 = 'custom_perform_2'
      end
      .provide(:param_1, :param_2, :param_3)
    end
  end

  it 'should process callbacks for perform' do
    result, param_1, param_2, param_3 = Cis::Interactor.perform

    expect(param_1).to eq('perform_1')
    expect(param_2).to eq('perform_2')
    expect(param_3).to eq('perform_3')
  end
  
  it 'should process callbacks for custom perform' do
    result, param_1, param_2, param_3 = Cis::Interactor.custom_perform

    expect(param_1).to eq('custom_perform_1')
    expect(param_2).to eq('custom_perform_2')
    expect(param_3).to eq('custom_perform_3')
  end
end
