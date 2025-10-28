# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class CallRule < DelegatingRule
          handles Aurora::AST::Call, method: :transform_call
        end
      end
    end
  end
end
