# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering HighIR return statements to C++ return statements
        class ReturnRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::Return)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            if node.expr
              # Return with expression
              expr = lowerer.send(:lower_expression, node.expr)
              CppAst::Nodes::ReturnStatement.new(expression: expr)
            else
              # Void return
              CppAst::Nodes::ReturnStatement.new(expression: nil, keyword_suffix: " ")
            end
          end
        end
      end
    end
  end
end
