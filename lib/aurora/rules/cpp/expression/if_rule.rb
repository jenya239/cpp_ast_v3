# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR if expressions to C++ ternary or statement-based if
        class IfRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::IfExpr], method: :lower_if
        end
      end
    end
  end
end
