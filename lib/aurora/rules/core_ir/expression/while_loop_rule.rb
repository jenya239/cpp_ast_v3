# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class WhileLoopRule < DelegatingRule
          handles Aurora::AST::WhileLoop, method: :transform_while_loop
        end
      end
    end
  end
end
