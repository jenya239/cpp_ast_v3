# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class ContinueRule < DelegatingRule
          handles Aurora::AST::Continue, method: :transform_continue_statement
        end
      end
    end
  end
end
