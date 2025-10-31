# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Statement
        # ExprStmtRule: Transform AST expression statements to HighIR
        # Contains FULL logic (no delegation to transformer)
        # Handles special cases: loops, if-expressions, blocks
        class ExprStmtRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::ExprStmt)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            expr = node.expr

            # Handle different expression types in statement position
            case expr
            when MLC::AST::ForLoop
              # For-loop as statement
              [expr_svc.transform_for_statement(expr)]

            when MLC::AST::IfExpr
              # If-expression as statement
              [expr_svc.transform_if_statement(expr.condition, expr.then_branch, expr.else_branch)]

            when MLC::AST::WhileLoop
              # While-loop as statement
              [expr_svc.transform_while_statement(expr.condition, expr.body)]

            when MLC::AST::Block
              # Block expression as statement (flatten statements)
              expr_svc.transform_block(expr, require_value: false).statements

            else
              # General expression as statement
              ir = expr_svc.transform_expression(expr)

              # Special case: if-expression with unit type - convert to if-statement
              if expr.is_a?(MLC::AST::IfExpr) && ir.is_a?(MLC::HighIR::IfExpr)
                MLC::HighIR::Builder.if_stmt(
                  ir.condition,
                  expr_svc.transform_statement_block(expr.then_branch),
                  expr.else_branch ? expr_svc.transform_statement_block(expr.else_branch) : nil
                )
                []
              else
                # Wrap expression in expression statement
                [MLC::HighIR::Builder.expr_statement(ir)]
              end
            end
          end
        end
      end
    end
  end
end
