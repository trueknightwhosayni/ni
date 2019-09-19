require 'rails_helper'

RSpec.describe 'Single interactor spec' do
  module Sis
    class Interactor1
      include Ni::Main

      receive :param_1

      action :perform do
        self.context.errors.add(:base, 'An error') if context.param_1 == '2'
      end
    end

    class Interactor2
      include Ni::Main

      def perform
        # not need to return any
      end
    end

    class Interactor3
      include Ni::Main

      receive :param_1

      def perform
        self.context.errors.add(:base, 'An error') if context.param_1 == '2'
      end
    end

    class Interactor3
      include Ni::Main

      mutate :param_1

      action :create do
        context.param_1 = 'new_value'
      end
    end

    class Interactor4
      include Ni::Main

      receive :custom_option
      mutate :param_1

      action :create do
        if context.custom_option
          context.param_1 = 'new_value_1'
        else
          context.param_1 = 'new_value'
        end
      end

      def self.create!(params={})
        create params.merge(custom_option: true)
      end
    end

    class Interactor5
      include Ni::Main

      receive :custom_option
      mutate :param_1

      action :create do
        if context.custom_option
          context.param_1 = 'new_value_1'
        else
          context.param_1 = 'new_value'
        end
      end

      def self.create(params={})
        perform_custom :create, params.merge(custom_option: true)
      end
    end

    class Interactor6
      include Ni::Main

      def perform
        context.param_1 = context.param_2
      end
    end
  end

  describe '#perform' do
    context 'success' do
      subject { Sis::Interactor1.perform(param_1: '1').success? }

      it { is_expected.to eq true }
    end

    context 'fail' do
      subject { Sis::Interactor1.perform(param_1: '2').success? }

      it { is_expected.to eq false }
    end

    context 'the most simple interactor' do
      subject { Sis::Interactor2.perform.success? }

      it { is_expected.to eq true }
    end

    context 'simple interactor with custom option' do
      subject { Sis::Interactor3.perform(param_1: '1').success? }

      it { is_expected.to eq true }
    end

    context 'when custom action' do
      context 'auto defined function' do
        subject { Sis::Interactor3.create(param_1: '1').context.param_1 }

        it { is_expected.to eq 'new_value'}
      end

      context 'user defined function' do
        subject { Sis::Interactor4.create!(param_1: '1').context.param_1 }

        it { is_expected.to eq 'new_value_1'}
      end

      context 'redefined interface' do
        subject { Sis::Interactor5.create(param_1: '1').context.param_1 }

        it { is_expected.to eq 'new_value_1'}
      end

      context 'should allow all read and writes until any rules speciied' do
        subject { Sis::Interactor6.perform(param_2: '1').context.param_1 }

        it { is_expected.to eq '1'}
      end
    end
  end
end
