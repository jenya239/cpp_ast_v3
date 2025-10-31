# frozen_string_literal: true

require_relative "../../base_rule"

module Aurora
  module Rules
    module CodeGen
      module Statement
        # Rule for lowering CoreIR if statements to C++ if statements
        class IfRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::CoreIR::IfStmt)
          end

          def apply(node, context = {})
            lowerer = context[:lowerer]

            # Lower condition
            condition = lowerer.send(:lower_expression, node.condition)

            # Lower then and else branches
            then_statement = lowerer.send(:lower_statement_block, node.then_body)
            else_statement = node.else_body ? lowerer.send(:lower_statement_block, node.else_body) : nil

            CppAst::Nodes::IfStatement.new(
              condition: condition,
              then_statement: then_statement,
              else_statement: else_statement,
              if_suffix: " ",
              condition_lparen_suffix: "",
              condition_rparen_suffix: "",
              else_prefix: " ",
              else_suffix: " "
            )
          end
        end
      end
    end
  end
end
