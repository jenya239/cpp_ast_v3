# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class LambdaRule < DelegatingRule
          handles Aurora::AST::Lambda, method: :transform_lambda
        end
      end
    end
  end
end
