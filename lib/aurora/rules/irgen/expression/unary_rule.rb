# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # UnaryRule: Transform AST unary operations to CoreIR unary expressions
        # Contains FULL logic (no delegation to transformer)
        # Recursive transformation via transformer from context
        class UnaryRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::UnaryOp)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Recursively transform operand
            operand = transformer.send(:transform_expression, node.operand)

            # Infer unary operation result type
            type = transformer.send(:infer_unary_type, node.op, operand.type)

            # Build CoreIR unary expression
            Aurora::CoreIR::Builder.unary(node.op, operand, type)
          end
        end
      end
    end
  end
end
