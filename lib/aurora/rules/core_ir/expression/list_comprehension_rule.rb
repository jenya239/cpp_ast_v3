# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class ListComprehensionRule < DelegatingRule
          handles Aurora::AST::ListComprehension, method: :transform_list_comprehension
        end
      end
    end
  end
end
