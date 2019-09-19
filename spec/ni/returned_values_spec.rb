require 'rails_helper'

RSpec.describe 'Returned values spec' do
  module Rvs
    class Interactor1
      include Ni::Main

      provide :a
      provide :b
      provide :c

      action :perform do
        context.a = 1
        context.b = 2
        context.c = 3
      end
    end

    class Interactor2
      include Ni::Main

      provide :a
      provide :b
      provide :c

      action :perform do
        context.a = 1
        context.b = 2
        context.c = 3
      end
      .provide(:c)
    end
  end

  describe '#perform' do
    context 'when all output contracts should make an outputs' do
      specify do
        result, a, b, c = Rvs::Interactor1.perform

        expect(result.success?).to eq true
        expect(a).to eq 1
        expect(b).to eq 2
        expect(c).to eq 3
      end
    end

    context 'when only specified params should make an outputs' do
      specify do
        result, c = Rvs::Interactor2.perform

        expect(result.success?).to eq true
        expect(c).to eq 3
        expect(result.context.a).to eq 1
        expect(result.context.b).to eq 2
      end
    end
  end
end
