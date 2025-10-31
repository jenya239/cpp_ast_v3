# frozen_string_literal: true

require_relative "../../base_rule"

module MLC
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering HighIR while statements to C++ while loops
        class WhileRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(MLC::HighIR::WhileStmt)
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
