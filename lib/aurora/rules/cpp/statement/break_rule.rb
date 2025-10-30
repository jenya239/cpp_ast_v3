# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR break statements to C++ break statements
        class BreakRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::BreakStmt], method: :lower_break_stmt
        end
      end
    end
  end
end
