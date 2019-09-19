require 'rails_helper'

RSpec.describe 'Branches spec' do
  module Bs
    class Level1NotUsedBranch
      include Ni::Main

      def perform
        raise 'Should not be here'
      end
    end

    class Level2NotUsedBranch
      include Ni::Main

      def perform
        raise 'Should not be here'
      end
    end

    class Level2ValidBranch
      include Ni::Main

      mutate :param_1

      action :perform do
        context.param_1 = 20
      end
    end

    class Level1ValidBranch
      include Ni::Main

      receive :param_1

      action :perform do
      end
        .branch(Bs::Level2ValidBranch, when: -> (context) { context.param_1 == 10 })
        .branch(Bs::Level2NotUsedBranch, when: -> (context) { context.param_1 == 666 })
    end

    class Organizer1
      include Ni::Main

      mutate :param_1

      action :perform do
        context.param_1 = 1
      end
        .branch(Bs::Level1NotUsedBranch, when: -> (context) { context.param_1 == 666 })
        .branch :first_level_valid_branch, when: -> (context) { context.param_1 == 1 } do
          
          receive :param_1

          action :perform do
          end
            .branch :second_level_valid_branch, when: -> (context) { context.param_1 == 1 } do
              mutate :param_1

              action :perform do
                context.param_1 = 2
              end
            end
            .branch(Bs::Level2NotUsedBranch, when: -> (context) { context.param_1 == 666 })
        end  
    end

    class Organizer2
      include Ni::Main

      mutate :param_1

      action :perform do
        context.param_1 = 10
      end
        .branch(Bs::Level1NotUsedBranch, when: -> (context) { context.param_1 == 666 })
        .branch(Bs::Level1ValidBranch, when: -> (context) { context.param_1 == 10 })
    end
  end

  it 'should go to second branch and then to first in subranch' do
    expect(Bs::Organizer1.perform.context.param_1).to eq 2
  end

  it 'should work as well for interactors' do
    expect(Bs::Organizer2.perform.context.param_1).to eq 20
  end  
end
