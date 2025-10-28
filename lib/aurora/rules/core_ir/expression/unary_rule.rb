# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class UnaryRule < DelegatingRule
          handles Aurora::AST::UnaryOp, method: :transform_unary
        end
      end
    end
  end
end
