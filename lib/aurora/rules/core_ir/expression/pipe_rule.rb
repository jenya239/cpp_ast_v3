# frozen_string_literal: true

require_relative "../../../rules/base_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class PipeRule < BaseRule
          def applies?(node, _context = {})
            node.is_a?(Aurora::AST::BinaryOp) && node.op == "|>"
          end

          def apply(node, context = {})
            context.fetch(:transformer).__send__(:transform_pipe, node)
          end
        end
      end
    end
  end
end
