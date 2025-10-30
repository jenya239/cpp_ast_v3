# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR continue statements to C++ continue statements
        class ContinueRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::ContinueStmt], method: :lower_continue_stmt
        end
      end
    end
  end
end
