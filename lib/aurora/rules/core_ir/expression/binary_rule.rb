# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class BinaryRule < DelegatingRule
          handles Aurora::AST::BinaryOp, method: :transform_binary

          def applies?(node, context = {})
            super && node.op != "|>"
          end
        end
      end
    end
  end
end
