# frozen_string_literal: true

require_relative "../../delegating_rule"

module Aurora
  module Rules
    module CoreIR
      module Expression
        class MemberRule < DelegatingRule
          handles Aurora::AST::MemberAccess, method: :transform_member_access
        end
      end
    end
  end
end
