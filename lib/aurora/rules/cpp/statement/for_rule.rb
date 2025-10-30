# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR for statements to C++ for loops
        class ForRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::ForStmt], method: :lower_for_stmt
        end
      end
    end
  end
end
