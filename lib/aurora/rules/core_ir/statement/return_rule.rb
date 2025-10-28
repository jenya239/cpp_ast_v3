# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class ReturnRule < DelegatingRule
          handles Aurora::AST::Return, method: :transform_return_statement

          def apply(node, context = {})
            Array(super)
          end
        end
      end
    end
  end
end
