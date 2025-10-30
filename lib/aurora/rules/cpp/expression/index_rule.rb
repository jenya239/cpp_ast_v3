# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR index access expressions to C++ array/vector indexing
        class IndexRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::IndexExpr], method: :lower_index
        end
      end
    end
  end
end
