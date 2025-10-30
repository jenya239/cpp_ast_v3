# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module Cpp
      module Expression
        # Rule for lowering CoreIR unary expressions to C++ unary operators
        class UnaryRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::UnaryExpr)
          end

          def apply(node, context = {})
            return node unless applies?(node, context)

            lowerer = context[:lowerer]
            operand = lowerer.send(:lower_expression, node.operand)

            CppAst::Nodes::UnaryExpression.new(
              operator: node.op,
              operand: operand,
              operator_suffix: node.op == "!" ? "" : "",
              prefix: true
            )
          end
        end
      end
    end
  end
end
