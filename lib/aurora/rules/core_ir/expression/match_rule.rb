# frozen_string_literal: true

require_relative "../../../rules/base_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class MatchRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::MatchExpr)
          end

          def apply(node, context = {})
            transformer = context.fetch(:transformer)
            transformer.__send__(:transform_match_expr, node)
          end
        end
      end
    end
  end
end
