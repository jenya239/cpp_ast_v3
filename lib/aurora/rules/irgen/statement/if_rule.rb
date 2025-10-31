# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Statement
        # IfRule: Transform AST if statements to CoreIR
        # Contains FULL logic (no delegation to transformer)
        class IfRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::IfStmt)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Transform condition and validate boolean type
            condition_ir = transformer.send(:transform_expression, node.condition)
            transformer.send(:ensure_boolean_type, condition_ir.type, "if condition", node: node.condition)

            # Transform then and else branches
            then_ir = transformer.send(:transform_statement_block, node.then_branch)
            else_ir = node.else_branch ? transformer.send(:transform_statement_block, node.else_branch) : nil

            # Build if statement
            [Aurora::CoreIR::Builder.if_stmt(condition_ir, then_ir, else_ir)]
          end
        end
      end
    end
  end
end
