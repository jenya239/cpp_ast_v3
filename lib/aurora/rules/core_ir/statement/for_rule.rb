# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class ForRule < DelegatingRule
          handles Aurora::AST::ForLoop, method: :transform_for_statement

          def apply(node, context = {})
            Array(super)
          end
        end
      end
    end
  end
end
