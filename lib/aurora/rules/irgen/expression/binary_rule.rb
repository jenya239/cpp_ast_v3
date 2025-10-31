# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        # BinaryRule: Transform AST binary operations to CoreIR binary expressions
        # Contains FULL logic (no delegation to transformer)
        # Recursive transformation via transformer from context
        class BinaryRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::BinaryOp) && node.op != "|>"
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)

            # Recursively transform left and right operands
            left = transformer.send(:transform_expression, node.left)
            right = transformer.send(:transform_expression, node.right)

            # Infer binary operation result type
            type = transformer.send(:infer_binary_type, node.op, left.type, right.type)

            # Build CoreIR binary expression
            Aurora::CoreIR::Builder.binary(node.op, left, right, type)
          end
        end
      end
    end
  end
end
