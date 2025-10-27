# frozen_string_literal: true

module Aurora
  module TypeSystem
    class EffectAnalyzer
      DEFAULT_EFFECTS = [:noexcept].freeze

      def initialize(pure_expression:, default_effects: DEFAULT_EFFECTS)
        @pure_expression = pure_expression
        @default_effects = Array(default_effects).dup.freeze
      end

      def analyze(body)
        return @default_effects.dup if body.nil?

        effects = @default_effects.dup
        effects.unshift(:constexpr) if @pure_expression.call(body)
        effects.uniq
      end
    end
  end
end
