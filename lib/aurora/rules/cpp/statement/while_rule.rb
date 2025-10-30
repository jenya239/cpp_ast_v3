# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module Cpp
      module Statement
        # Rule for lowering CoreIR while statements to C++ while loops
        class WhileRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::WhileStmt)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Lower condition and body
            condition = lowerer.send(:lower_expression, node.condition)
            body_statement = lowerer.send(:lower_statement_block, node.body)

            CppAst::Nodes::WhileStatement.new(
              condition: condition,
              body: body_statement,
              while_suffix: " ",
              condition_lparen_suffix: "",
              condition_rparen_suffix: ""
            )
          end
        end
      end
    end
  end
end
