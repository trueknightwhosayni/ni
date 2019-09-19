require 'rails_helper'

RSpec.describe 'SkipTheRestChain spec' do
  module Strc
    class Level2NotUsedBranch
      include Ni::Main

      mutate :test

      action :perform do
        self.context.test = 111
        self.context.skip_the_rest_chain!       
      end
      .then do
        raise 'Should not be here'
      end
    end

    class Level1NotUsedBranch
      include Ni::Main

      mutate :param_2
      mutate :param_3

      action :perform do
        context.param_2 = 'param 2'
      end          
      .then(Strc::Level2NotUsedBranch)
      .then do
        context.param_3 = 'param 3'
      end
    end  

    class Organizer1
      include Ni::Main

      mutate :param_1

      action :perform do
        context.param_1 = 1
      end
      .then(Strc::Level1NotUsedBranch, when: -> (context) { context.param_1 == 666 }) 
      .then do
        context.param_1 = 2
      end 
    end
  end

  it 'should go to Level1NotUsedBranch and to Level2NotUsedBranch but the second one should be skipped' do
    result = Strc::Organizer1.perform

    expect(result.context.param_1).to eq 2
    expect(result.context.param_2).to eq 'param 2'
    expect(result.context.param_3).to eq 'param 3'
  end
end
