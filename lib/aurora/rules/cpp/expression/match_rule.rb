# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR match expressions to C++ switch/if chains
        class MatchRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::MatchExpr], method: :lower_match
        end
      end
    end
  end
end
