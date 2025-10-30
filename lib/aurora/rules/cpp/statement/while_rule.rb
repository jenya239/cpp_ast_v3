# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR while statements to C++ while loops
        class WhileRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::WhileStmt], method: :lower_while_stmt
        end
      end
    end
  end
end
