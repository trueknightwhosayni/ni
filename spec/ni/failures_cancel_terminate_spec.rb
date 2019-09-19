require 'rails_helper'

RSpec.describe 'Failures spec' do
  module Fs
    class Interactor1
      include Ni::Main

      def perform
        context.errors.add :base, 'Something went wrong'
      end
    end

    class Interactor2
      include Ni::Main

      provide :param_1

      def perform
        raise "Shouldn't be here"
      end
    end

    class Organizer1
      include Ni::Main

      provide :failure_value

      action :perform do
        # empty initializer
      end
      .then(Fs::Interactor1)
      .then(Fs::Interactor2)
      .failure do
        context.failure_value = 'fail'
      end
    end

    class Organizer2
      include Ni::Main

      action :perform do
        # empty initializer
      end
      .then(Fs::Interactor1)
      .then(Fs::Interactor2)
    end

    class Organizer3
      include Ni::Main

      provide :failure_value
      provide :step_failure_value

      action :perform do
        # empty initializer
      end
      .then(Fs::Interactor1, on_failure: -> { context.step_failure_value = 'step failed' })
      .then(Fs::Interactor2)
      .failure do
        context.failure_value = 'fail'
      end
    end

    class FailureProcessor
      include Ni::Main

      provide :step_failure_value

      def perform
        context.step_failure_value = 'step failed'
      end
    end

    class Organizer4
      include Ni::Main

      provide :failure_value
      provide :step_failure_value

      action :perform do
        # empty initializer
      end
      .then(Fs::Interactor1, on_failure: Fs::FailureProcessor)
      .then(Fs::Interactor2)
      .failure do
        context.failure_value = 'fail'
      end
    end

    class CancelInteractor
      include Ni::Main

      action :perform do
      end
      .cancel!  
    end

    class Organizer5
      include Ni::Main

      provide :step_cancel_value
      provide :cancel_value

      action :perform do
        # empty initializer
      end
      .then(Fs::CancelInteractor, on_cancel: -> { context.step_cancel_value = 'step canceled' })
      .then(Fs::Interactor2)

      def on_cancel(action_name)
        context.cancel_value = 'canceled'
      end  
    end

    class TerminateLevel2Interactor
      include Ni::Main

      action :perform do
      end
      .terminate!  
    end

    class TerminateLevel1Interactor
      include Ni::Main

      action :perform do
      end
      .then(Fs::TerminateLevel2Interactor)  
    end

    class Organizer6
      include Ni::Main

      provide :step_terminate_value
      provide :terminate_value

      action :perform do
        # empty initializer
      end
      .then(Fs::TerminateLevel1Interactor, on_terminate: -> { context.step_terminate_value = 'step terminated' })
      .then(Fs::Interactor2)

      def on_terminate(action_name)
        context.terminate_value = 'terminated'
      end  
    end

    class Organizer7
      include Ni::Main

      provide :top_level_failure_value

      action :perform do
        # empty initializer
      end
      .then(Fs::Organizer1)
      .then(Fs::Interactor2)

      def on_failure(action_name)
        context.top_level_failure_value = 'failed'
      end 
    end

    class SuccessLevel2Interactor
      include Ni::Main

      action :perform do
      end
      .then do
        context.success!
      end
      .then(Fs::Interactor2)        
    end

    class SuccessLevel1Interactor
      include Ni::Main

      action :perform do
      end
      .then(Fs::SuccessLevel2Interactor)  
    end

    class Organizer8
      include Ni::Main

      provide :success_value

      action :perform do
        context.success_value = 1
      end
      .then(Fs::SuccessLevel1Interactor)
      .then(Fs::Interactor2)
    end
  end

  context 'should not pass to Interactor2 but should perform the failure callback' do
    let!(:result) { Fs::Organizer1.perform }

    specify do
      expect(result.success?).to eq false
      expect(result.context.param_1).to eq nil
      expect(result.context.failure_value).to eq 'fail'
    end
  end

  context 'should not pass to Interactor2 and skip the failure callback' do
    let!(:result) { Fs::Organizer2.perform }

    specify do
      expect(result.success?).to eq false
      expect(result.context.param_1).to eq nil
    end
  end

  context 'should call lambda on failure' do
    let!(:result) { Fs::Organizer3.perform }

    specify do
      expect(result.success?).to eq false
      expect(result.context.param_1).to eq nil
      expect(result.context.step_failure_value).to eq 'step failed'
      expect(result.context.failure_value).to eq 'fail'
    end
  end

  context 'should perform interactor on failure' do
    let!(:result) { Fs::Organizer4.perform }

    specify do
      expect(result.success?).to eq false
      expect(result.context.param_1).to eq nil
      expect(result.context.step_failure_value).to eq 'step failed'
      expect(result.context.failure_value).to eq 'fail'
    end
  end

  context 'should call lambda on cancel' do
    let!(:result) { Fs::Organizer5.perform }

    specify do
      expect(result.success?).to eq false
      expect(result.context.param_1).to eq nil
      expect(result.context.step_cancel_value).to eq 'step canceled'
      expect(result.context.cancel_value).to eq 'canceled'
    end
  end

  context 'should call lambda on terminate' do
    let!(:result) { Fs::Organizer6.perform }

    specify do
      expect(result.success?).to eq false
      expect(result.context.param_1).to eq nil
      expect(result.context.step_terminate_value).to eq 'step terminated'
      expect(result.context.terminate_value).to eq 'terminated'
    end
  end

  context 'termination should work with different levels' do
    let!(:result) { Fs::Organizer7.perform }

    specify do
      expect(result.success?).to eq false
      expect(result.context.failure_value).to eq 'fail'
      expect(result.context.top_level_failure_value).to eq 'failed'
    end
  end

  context 'success should work with different levels' do
    let!(:result) { Fs::Organizer8.perform }

    specify do
      expect(result.success?).to eq true
      expect(result.context.success_value).to eq 1
    end
  end
end
