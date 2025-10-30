# frozen_string_literal: true

require_relative "../cpp_statement_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR return statements to C++ return statements
        class ReturnRule < CppStatementRule
          handles_cpp_stmt [Aurora::CoreIR::Return], method: :lower_return_stmt
        end
      end
    end
  end
end
