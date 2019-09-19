require 'rails_helper'

RSpec.describe 'Contracts spec' do
  module Cs
    class Interactor1
      include Ni::Main

      receive :param_1
      mutate :param_2
      provide :param_3

      action :perform do
        #do nothing
      end
    end

    class Interactor2
      include Ni::Main

      receive :param_1, :present?
      mutate :param_2, :zero?
      provide :param_3, :zero?

      action :perform do
        context.param_3 = 1
      end
    end

    class Interactor3
      include Ni::Main

      receive :param_1, -> (val) { val == true }
      mutate :param_2, -> (val) { val == 0 }
      provide :param_3, -> (val) { val == 0 }

      action :perform do
        context.param_3 = 1
      end
    end

    class Interactor4
      include Ni::Main

      action :perform do
        context.param_1
      end
    end

    class Interactor5
      include Ni::Main

      receive :param_1

      action :perform do
        context.param_2 = context.param_1
      end
    end

    class Interactor6
      include Ni::Main

      receive :param_1
      mutate :param_2
      provide :param_3

      action :perform do
        context.param_2 = context.param_1 + 1
        context.param_3 = context.param_2 + 2
      end
    end
  end

  context 'when params are not passed contracts should be explicit' do
    subject { Cs::Interactor1.perform.success? }

    it { is_expected.to eq true }
  end

  context 'when method contract' do
    specify do
      expect { Cs::Interactor2.perform }.to raise_error("Value of `param_1` doesn't match to contract :present?")
      expect { Cs::Interactor2.perform(param_1: true, param_2: 1) }.to raise_error("Value of `param_2` doesn't match to contract :zero?")
      expect { Cs::Interactor2.perform(param_1: true, param_2: 0) }.to raise_error("Value of `param_3` doesn't match to contract :zero?")
      expect { Cs::Interactor2.perform(param_1: true, param_2: '0') }.to raise_error("Value of `param_2` doesn't respond to contract method :zero?")
    end
  end

  context 'when method contract' do
    specify do
      expect { Cs::Interactor3.perform }.to raise_error("Value of `param_1` doesn't match to contract")
      expect { Cs::Interactor3.perform(param_1: true, param_2: 1) }.to raise_error("Value of `param_2` doesn't match to contract")
      expect { Cs::Interactor3.perform(param_1: true, param_2: 0) }.to raise_error("Value of `param_3` doesn't match to contract")
    end
  end

  context 'should raise errors when access rules are not passed' do
    specify do
      expect { Cs::Interactor5.perform(param_1: 1) }.to raise_error("The `param_2` is not allowed to write")
    end
  end

  context 'should allow to read/write/mutate' do
    subject { Cs::Interactor6.perform(param_1: 1).success? }

    it { is_expected.to eq true }
  end
end
