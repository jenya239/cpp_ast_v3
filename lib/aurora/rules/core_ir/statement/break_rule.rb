# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class BreakRule < DelegatingRule
          handles Aurora::AST::Break, method: :transform_break_statement
        end
      end
    end
  end
end
