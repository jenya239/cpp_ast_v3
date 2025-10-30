# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR function call expressions to C++ function calls
        class CallRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::CallExpr], method: :lower_call
        end
      end
    end
  end
end
