# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class ArrayLiteralRule < DelegatingRule
          handles Aurora::AST::ArrayLiteral, method: :transform_array_literal
        end
      end
    end
  end
end
