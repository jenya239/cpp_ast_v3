# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR if statements to C++ if statements
        class IfRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::IfStmt], method: :lower_if_stmt
        end
      end
    end
  end
end
