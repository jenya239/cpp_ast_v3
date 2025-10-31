# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Statement
        # IfRule: Transform AST if statements to HighIR
        # Contains FULL logic (no delegation to transformer)
        class IfRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::IfStmt)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)

            # Transform condition and validate boolean type
            condition_ir = expr_svc.transform_expression(node.condition)
            type_checker.ensure_boolean(condition_ir.type, "if condition", node: node.condition)

            # Transform then and else branches
            then_ir = expr_svc.transform_statement_block(node.then_branch)
            else_ir = node.else_branch ? expr_svc.transform_statement_block(node.else_branch) : nil

            # Build if statement
            [MLC::HighIR::Builder.if_stmt(condition_ir, then_ir, else_ir)]
          end
        end
      end
    end
  end
end
