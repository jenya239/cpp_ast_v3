# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR variable declarations to C++ variable declarations
        class VariableDeclRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::VariableDeclStmt], method: :lower_variable_decl_stmt
        end
      end
    end
  end
end
