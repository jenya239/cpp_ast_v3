# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR list comprehension expressions to C++ loops
        class ListCompRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::ListCompExpr], method: :lower_list_comprehension
        end
      end
    end
  end
end
