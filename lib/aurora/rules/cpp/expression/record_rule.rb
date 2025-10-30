# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR record expressions to C++ struct initialization
        class RecordRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::RecordExpr], method: :lower_record
        end
      end
    end
  end
end
