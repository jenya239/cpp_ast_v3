# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # DoRule: Transform AST do-expressions to CoreIR by normalizing to block expressions
        # Contains FULL logic (no delegation to transformer)
        # Normalizes legacy do-blocks into BlockExpr nodes
        class DoRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::DoExpr)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)

            # Handle empty do block
            if node.body.empty?
              block = Aurora::AST::BlockExpr.new(
                statements: [],
                result_expr: Aurora::AST::UnitLit.new(origin: node.origin),
                origin: node.origin
              )
              return expr_svc.transform_block_expr(block)
            end

            # Normalize do body items into block structure
            statements = []
            result_expr = nil

            node.body.each_with_index do |item, index|
              is_last = (index == node.body.length - 1)

              # Normalize let bindings without body to variable declarations
              normalized_node = if item.is_a?(Aurora::AST::Let) && item.body.nil?
                                  Aurora::AST::VariableDecl.new(
                                    name: item.name,
                                    value: item.value,
                                    mutable: item.mutable,
                                    type: item.type,
                                    origin: item.origin
                                  )
                                else
                                  item
                                end

              # Categorize node and build statements/result_expr
              case normalized_node
              when Aurora::AST::Stmt
                statements << normalized_node
                result_expr = Aurora::AST::UnitLit.new(origin: normalized_node.origin) if is_last
              when Aurora::AST::WhileLoop
                if is_last
                  statements << Aurora::AST::ExprStmt.new(expr: normalized_node, origin: normalized_node.origin)
                  result_expr = Aurora::AST::UnitLit.new(origin: normalized_node.origin)
                else
                  statements << Aurora::AST::ExprStmt.new(expr: normalized_node, origin: normalized_node.origin)
                end
              else
                # Expression node
                if is_last
                  result_expr = normalized_node
                else
                  statements << Aurora::AST::ExprStmt.new(expr: normalized_node, origin: normalized_node.origin)
                end
              end
            end

            # Ensure result expression exists
            result_expr ||= Aurora::AST::UnitLit.new(origin: node.origin)

            # Build normalized block and transform
            block = Aurora::AST::BlockExpr.new(statements: statements, result_expr: result_expr, origin: node.origin)
            expr_svc.transform_block_expr(block)
          end
        end
      end
    end
  end
end
