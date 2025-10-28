# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Statement
        class AssignmentRule < DelegatingRule
          handles Aurora::AST::Assignment, method: :transform_assignment_statement
        end
      end
    end
  end
end
