# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR expression statements to C++ expression statements
        class ExprStatementRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::ExprStatement], method: :lower_expr_statement
        end
      end
    end
  end
end
