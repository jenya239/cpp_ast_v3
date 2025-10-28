# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class ForLoopRule < DelegatingRule
          handles Aurora::AST::ForLoop, method: :transform_for_loop
        end
      end
    end
  end
end
