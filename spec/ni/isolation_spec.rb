require 'rails_helper'

RSpec.describe 'Isolation spec' do
  module Is
    class Interactor1
      include Ni::Main

      provide :param_1

      def perform
        context.param_1 = 1
      end
    end

    class Interactor2
      include Ni::Main

      mutate :param_1
      provide :param_2

      action :custom_action do
        context.param_2 = context.param_1 + 1
        context.param_1 = 25
      end
    end

    class Interactor3
      include Ni::Main

      receive :param_2
      provide :param_3

      def perform
        context.param_3 = context.param_2 + 1
      end
    end

    class Organizer1
      include Ni::Main

      mutate :param_1
      mutate :param_2
      mutate :param_3

      action :perform do
        # an empty initializer
      end
      .then(Is::Interactor1)
      .isolate(Is::Interactor2, :custom_action, receive: [:param_1], provide: [:param_2])
      .then(Is::Interactor3)
    end
  end

  context 'should pass through all steps' do
    let!(:result) { Is::Organizer1.perform }

    specify do
      expect(result.context.param_1).to eq 1
      expect(result.context.param_2).to eq 2
      expect(result.context.param_3).to eq 3
    end
  end

  context 'should provide errors as well', pending: true do
  end
end
