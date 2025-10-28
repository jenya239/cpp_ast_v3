# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class IfRule < DelegatingRule
          handles Aurora::AST::IfStmt, method: :transform_if_statement

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            Array(transformer.transform_if_statement(node.condition, node.then_branch, node.else_branch))
          end
        end
      end
    end
  end
end
