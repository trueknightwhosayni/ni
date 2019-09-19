module Ni
  class Result
    attr_reader :context

    delegate :success?, :valid?, :errors, to: :context

    def initialize(context, args=[])
      @context, @args = context, args
    end

    def to_ary
      [self] + @args
    end
  end
end
