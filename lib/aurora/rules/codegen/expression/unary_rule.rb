# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering CoreIR unary expressions to C++ unary operators
        # Contains logic, but delegates recursion to lowerer for operand
        class UnaryRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::UnaryExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Recursively lower operand
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
