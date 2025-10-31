# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # IfRule: Transform AST if expressions to CoreIR if expressions
        # Contains FULL logic (no delegation to transformer)
        # Handles both statement-like (unit type) and expression-like if
        class IfRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::IfExpr)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Transform condition and ensure it's boolean
            condition_ir = transformer.send(:transform_expression, node.condition)
            transformer.send(:ensure_boolean_type, condition_ir.type, "if condition", node: node.condition)

            # Check if both branches are unit type (statement-like)
            if transformer.send(:unit_branch_ast?, node.then_branch) &&
               (node.else_branch.nil? || transformer.send(:unit_branch_ast?, node.else_branch))
              # Statement-like if: wrap in block_expr
              then_block_ir = transformer.send(:transform_statement_block, node.then_branch)
              else_block_ir = node.else_branch ? transformer.send(:transform_statement_block, node.else_branch) : nil
              if_stmt = Aurora::CoreIR::Builder.if_stmt(condition_ir, then_block_ir, else_block_ir)
              unit_literal = Aurora::CoreIR::Builder.unit_literal
              Aurora::CoreIR::Builder.block_expr([if_stmt], unit_literal, unit_literal.type)
            else
              # Expression-like if: transform branches as expressions
              then_branch_ir = transformer.send(:transform_expression, node.then_branch)
              else_branch_ir = node.else_branch ? transformer.send(:transform_expression, node.else_branch) : nil

              # Infer type from branches
              type = if else_branch_ir
                       transformer.send(:ensure_compatible_type, else_branch_ir.type, then_branch_ir.type, "if expression branches")
                       then_branch_ir.type
                     else
                       Aurora::CoreIR::Builder.unit_type
                     end

              # Build CoreIR if expression
              Aurora::CoreIR::Builder.if_expr(condition_ir, then_branch_ir, else_branch_ir, type)
            end
          end
        end
      end
    end
  end
end
