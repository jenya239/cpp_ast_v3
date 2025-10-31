# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Statement
        # ExprStmtRule: Transform AST expression statements to CoreIR
        # Contains FULL logic (no delegation to transformer)
        # Handles special cases: loops, if-expressions, blocks
        class ExprStmtRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::ExprStmt)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr = node.expr

            # Handle different expression types in statement position
            case expr
            when Aurora::AST::ForLoop
              # For-loop as statement
              [transformer.send(:transform_for_statement, expr)]

            when Aurora::AST::IfExpr
              # If-expression as statement
              [transformer.send(:transform_if_statement, expr.condition, expr.then_branch, expr.else_branch)]

            when Aurora::AST::WhileLoop
              # While-loop as statement
              [transformer.send(:transform_while_statement, expr.condition, expr.body)]

            when Aurora::AST::Block
              # Block expression as statement (flatten statements)
              transformer.send(:transform_block, expr, require_value: false).statements

            else
              # General expression as statement
              ir = transformer.send(:transform_expression, expr)

              # Special case: if-expression with unit type - convert to if-statement
              if expr.is_a?(Aurora::AST::IfExpr) && ir.is_a?(Aurora::CoreIR::IfExpr)
                transformer.send(:CoreIR)::Builder.if_stmt(
                  ir.condition,
                  transformer.send(:transform_statement_block, expr.then_branch),
                  expr.else_branch ? transformer.send(:transform_statement_block, expr.else_branch) : nil
                )
                []
              else
                # Wrap expression in expression statement
                [Aurora::CoreIR::Builder.expr_statement(ir)]
              end
            end
          end
        end
      end
    end
  end
end
