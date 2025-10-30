# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR array literal expressions to C++ array/vector initialization
        class ArrayLiteralRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::ArrayLiteralExpr], method: :lower_array_literal
        end
      end
    end
  end
end
