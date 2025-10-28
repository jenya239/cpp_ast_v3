# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class WhileRule < DelegatingRule
          handles Aurora::AST::WhileStmt, method: :transform_while_statement

          def apply(node, context = {})
            Array(super)
          end
        end
      end
    end
  end
end
