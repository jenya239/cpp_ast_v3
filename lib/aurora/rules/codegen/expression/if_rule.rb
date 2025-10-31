# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module Aurora
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering CoreIR if expressions to C++ ternary operator
        # Unit-type ifs should be lowered as statements, not expressions
        class IfRule < BaseRule
          include Aurora::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::IfExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Unit type if-expressions should be lowered as statements, not expressions
            if should_lower_as_statement?(node)
              raise "Internal error: Unit type if-expression should not be lowered as expression. Use lower_if_expr_as_statement instead."
            end

            # Recursively lower all parts
            condition = lowerer.send(:lower_expression, node.condition)
            then_branch = lowerer.send(:lower_expression, node.then_branch)

            # For value-producing expressions, use ternary operator
            # If no else branch, default to 0 (shouldn't happen in well-typed code)
            else_branch = if node.else_branch
                           lowerer.send(:lower_expression, node.else_branch)
                         else
                           CppAst::Nodes::NumberLiteral.new(value: "0")
                         end

            CppAst::Nodes::TernaryExpression.new(
              condition: condition,
              true_expression: then_branch,
              false_expression: else_branch,
              question_prefix: " ",
              colon_prefix: " ",
              question_suffix: " ",
              colon_suffix: " "
            )
          end
        end
      end
    end
  end
end
