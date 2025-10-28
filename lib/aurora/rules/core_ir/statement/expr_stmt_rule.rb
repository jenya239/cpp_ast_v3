# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class ExprStmtRule < DelegatingRule
          handles Aurora::AST::ExprStmt, method: :transform_expr_statement
        end
      end
    end
  end
end
