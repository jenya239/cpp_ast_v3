# frozen_string_literal: true

module MLC
  module TypeSystem
    class EffectAnalyzer
      DEFAULT_EFFECTS = [:noexcept].freeze

      def initialize(pure_expression:, non_literal_type:, default_effects: DEFAULT_EFFECTS)
        @pure_expression = pure_expression
        @non_literal_type = non_literal_type
        @default_effects = Array(default_effects).dup.freeze
      end

      def analyze(body, return_type: nil)
        return @default_effects.dup if body.nil?

        effects = @default_effects.dup

        # Check if body is pure and return type is literal
        body_pure = @pure_expression.call(body)
        type_literal = return_type.nil? || !@non_literal_type.call(return_type)

        effects.unshift(:constexpr) if body_pure && type_literal
        effects.uniq
      end
    end
  end
end
