# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR member access expressions to C++ member access
        class MemberRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::MemberExpr], method: :lower_member
        end
      end
    end
  end
end
