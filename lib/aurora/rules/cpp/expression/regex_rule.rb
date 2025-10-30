# frozen_string_literal: true

require_relative "../cpp_expression_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR regex expressions to C++ aurora::Regex objects
        class RegexRule < CppExpressionRule
          handles_cpp_expr [Aurora::CoreIR::RegexExpr], method: :lower_regex
        end
      end
    end
  end
end
