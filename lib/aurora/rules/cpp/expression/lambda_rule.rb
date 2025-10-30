# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR lambda expressions to C++ lambda expressions
        class LambdaRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::LambdaExpr], method: :lower_lambda
        end
      end
    end
  end
end
