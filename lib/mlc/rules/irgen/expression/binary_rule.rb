# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module IRGen
      module Expression
        # BinaryRule: Transform AST binary operations to HighIR binary expressions
        # Contains FULL logic (no delegation to transformer)
        # Recursive transformation via transformer from context
        class BinaryRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::AST::BinaryOp) && node.op != "|>"
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            expr_svc = context.fetch(:expression_transformer)
            type_inference = context.fetch(:type_inference)

            # Recursively transform left and right operands
            left = expr_svc.transform_expression(node.left)
            right = expr_svc.transform_expression(node.right)

            # Infer binary operation result type
            type = type_inference.infer_binary_type(node.op, left.type, right.type)

            # Build HighIR binary expression
            MLC::HighIR::Builder.binary(node.op, left, right, type)
          end
        end
      end
    end
  end
end
