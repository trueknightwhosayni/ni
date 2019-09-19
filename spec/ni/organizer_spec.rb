require 'rails_helper'

RSpec.describe 'Organizer spec' do
  module Os
    class Interactor2
      include Ni::Main

      receive :param_2
      provide :param_3

      def perform
        context.param_3 = context.param_2 + 1
      end
    end

    class Interactor3
      include Ni::Main

      receive :param_4
      provide :param_5

      action :custom_action do
        context.param_5 = context.param_4 + 1
      end
    end

    class Organizer1
      include Ni::Main

      mutate :param_1
      mutate :param_2
      mutate :param_3
      mutate :param_4
      mutate :param_5
      mutate :final_value

      action :perform do
        context.param_1 = 1
      end
      .then(:step_1)
      .then(Os::Interactor2)
      .then do
        context.param_4 = context.param_3 + 1
      end
      .then(Os::Interactor3, :custom_action)
      .then(:step_2)
      .then do
        context.final_value = context.param_5 + 1
      end

      private

      def step_1
        context.param_2 = context.param_1 + 1
      end

      def step_2
        context.param_5 = context.param_4 + 1
      end
    end

    class Interactor4
      include Ni::Main

      def perform
        context.param_2 = 2
      end
    end

    class Interactor5
      include Ni::Main

      provide :param_2

      def perform
        context.param_2 = 2
      end
    end

    class Interactor6
      include Ni::Main

      receive :param_2
      provide :param_3

      def perform
        context.param_3 = context.param_2 + 1
      end
    end

    class Organizer2
      include Ni::Main

      mutate :param_1
      mutate :param_2

      action :perform do
        context.param_1 = 1
      end
      .then(Os::Interactor4)
    end

    class Organizer3
      include Ni::Main

      mutate :param_1
      mutate :param_2
      mutate :param_3

      action :perform do
        context.param_1 = 1
      end
      .then(Os::Interactor5)
      .then(Os::Interactor6)
    end
  end

  context 'should pass through all steps' do
    let!(:result) { Os::Organizer1.perform }

    specify do
      expect(result.context.param_1).to eq 1
      expect(result.context.param_2).to eq 2
      expect(result.context.param_3).to eq 3
      expect(result.context.param_4).to eq 4
      expect(result.context.param_5).to eq 5
      expect(result.context.final_value).to eq 6
    end
  end

  specify 'Should switch context back' do
    result = Os::Organizer3.perform
    expect(result.context.param_3).to eq 3
  end
end
