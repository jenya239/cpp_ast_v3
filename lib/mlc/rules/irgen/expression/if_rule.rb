# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Expression
        # IfRule: Transform AST if expressions to HighIR if expressions
        # Contains FULL logic (no delegation to transformer)
        # Handles both statement-like (unit type) and expression-like if
        class IfRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::IfExpr)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_checker = context.fetch(:type_checker)
            predicates = context.fetch(:predicates)

            # Transform condition and ensure it's boolean
            condition_ir = expr_svc.transform_expression(node.condition)
            type_checker.ensure_boolean(condition_ir.type, "if condition", node: node.condition)

            # Check if both branches are unit type (statement-like)
            if predicates.unit_branch?(node.then_branch) &&
               (node.else_branch.nil? || predicates.unit_branch?(node.else_branch))
              # Statement-like if: wrap in block_expr
              then_block_ir = expr_svc.transform_statement_block(node.then_branch)
              else_block_ir = node.else_branch ? expr_svc.transform_statement_block(node.else_branch) : nil
              if_stmt = MLC::HighIR::Builder.if_stmt(condition_ir, then_block_ir, else_block_ir)
              unit_literal = MLC::HighIR::Builder.unit_literal
              MLC::HighIR::Builder.block_expr([if_stmt], unit_literal, unit_literal.type)
            else
              # Expression-like if: transform branches as expressions
              then_branch_ir = expr_svc.transform_expression(node.then_branch)
              else_branch_ir = node.else_branch ? expr_svc.transform_expression(node.else_branch) : nil

              # Infer type from branches
              type = if else_branch_ir
                       type_checker.ensure_compatible(else_branch_ir.type, then_branch_ir.type, "if expression branches")
                       then_branch_ir.type
                     else
                       MLC::HighIR::Builder.unit_type
                     end

              # Build HighIR if expression
              MLC::HighIR::Builder.if_expr(condition_ir, then_branch_ir, else_branch_ir, type)
            end
          end
        end
      end
    end
  end
end
