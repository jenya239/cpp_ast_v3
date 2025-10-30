# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR match statements to C++ std::visit
        class MatchRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::MatchStmt], method: :lower_match_stmt
        end
      end
    end
  end
end
