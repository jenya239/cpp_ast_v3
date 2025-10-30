# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR assignment statements to C++ assignments
        class AssignmentRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::AssignmentStmt)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Lower left and right sides
            left_expr = lowerer.send(:lower_expression, node.target)
            right_expr = lowerer.send(:lower_expression, node.value)

            # Create assignment expression
            assignment = CppAst::Nodes::AssignmentExpression.new(
              left: left_expr,
              operator: "=",
              right: right_expr
            )

            # Wrap in expression statement
            CppAst::Nodes::ExpressionStatement.new(expression: assignment)
          end
        end
      end
    end
  end
end
