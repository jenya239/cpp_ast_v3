# frozen_string_literal: true

require_relative "../../base_rule"
require_relative "../../../backend/codegen/helpers"

module MLC
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering HighIR expression statements to C++ expression statements
        class ExprStatementRule < BaseRule
          include MLC::Backend::CodeGenHelpers

          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::ExprStatement)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            if should_lower_as_statement?(node.expression)
              # Expression with unit type should be lowered as statement
              # Currently only IfExpr with unit type
              if node.expression.is_a?(MLC::HighIR::IfExpr)
                # Delegate to IfRule (statement version)
                # This will be handled by calling lower_if_expr_as_statement through lowerer
                lowerer.send(:lower_if_expr_as_statement, node.expression)
              else
                raise "Unknown statement-like expression: #{node.expression.class}"
              end
            else
              expr = lowerer.send(:lower_expression, node.expression)
              CppAst::Nodes::ExpressionStatement.new(expression: expr)
            end
          end
        end
      end
    end
  end
end
