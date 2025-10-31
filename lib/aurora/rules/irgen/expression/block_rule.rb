# frozen_string_literal: true

require_relative "../../../rules/base_rule"

module Aurora
  module Rules
    module IRGen
      module Expression
        class BlockRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::BlockExpr)
          end

          def apply(node, context = {})
            context.fetch(:transformer).__send__(:transform_block_expr, node)
          end
        end
      end
    end
  end
end
