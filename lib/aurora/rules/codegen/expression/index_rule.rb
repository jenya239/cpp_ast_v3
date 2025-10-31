# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module CodeGen
      module Expression
        # Rule for lowering CoreIR index access to C++ array subscript ([])
        # Contains logic, delegates recursion to lowerer for array and index expressions
        class IndexRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::IndexExpr)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Recursively lower array and index expressions
            array = lowerer.send(:lower_expression, node.object)
            index = lowerer.send(:lower_expression, node.index)

            CppAst::Nodes::ArraySubscriptExpression.new(
              array: array,
              index: index
            )
          end
        end
      end
    end
  end
end
