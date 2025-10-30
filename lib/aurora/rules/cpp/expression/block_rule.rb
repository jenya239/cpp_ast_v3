# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR block expressions to C++ blocks
        class BlockRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::BlockExpr], method: :lower_block_expr
        end
      end
    end
  end
end
