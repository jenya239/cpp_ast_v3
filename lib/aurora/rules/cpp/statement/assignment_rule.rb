# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR assignment statements to C++ assignments
        class AssignmentRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::AssignmentStmt], method: :lower_assignment_stmt
        end
      end
    end
  end
end
