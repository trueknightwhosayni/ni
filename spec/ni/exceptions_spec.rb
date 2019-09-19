require 'rails_helper'

RSpec.describe 'Exceptions spec' do
  module Es
    class Ex1 < Exception
    end

    class Ex2 < Exception
    end

    class Interactor1
      include Ni::Main

      def perform
        raise Es::Ex2.new
      end
    end

    class Interactor2
      include Ni::Main

      provide :param_1

      def perform
        context.param_1 = 1
      end
    end

    class Organizer1
      include Ni::Main

      provide :exception_value

      action :perform do
        # empty initializer
      end
      .then(Es::Interactor1)
      .then(Es::Interactor2)
      .rescue_from Es::Ex1, Es::Ex2 do
        context.exception_value = 'fail'
      end
    end

    class Organizer2
      include Ni::Main

      provide :exception_value

      action :perform do
        # empty initializer
      end
      .then(Es::Interactor1)
      .then(Es::Interactor2)
      .rescue_from do
        context.exception_value = 'fail'
      end
    end

    class Organizer3
      include Ni::Main

      action :perform do
        # empty initializer
      end
      .then(Es::Interactor1)
      .then(Es::Interactor2)
    end
  end

  context 'should not pass to Interactor2 but should catch the exception callback' do
    context 'when exception list was specified' do
      let!(:result) { Es::Organizer1.perform }

      specify do
        expect(result.success?).to eq false
        expect(result.context.param_1).to eq nil
        expect(result.context.exception_value).to eq 'fail'
      end
    end

    context 'when default handler' do
      let!(:result) { Es::Organizer2.perform }

      specify do
        expect(result.success?).to eq false
        expect(result.context.param_1).to eq nil
        expect(result.context.exception_value).to eq 'fail'
      end
    end
  end

  context 'should not pass to Interactor2 and skip the failure callback' do
    specify do
      expect { Es::Organizer3.perform }.to raise_error(Es::Ex2)
    end
  end
end
