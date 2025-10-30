# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR return statements to C++ return statements
        class ReturnRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::ReturnStmt)
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
