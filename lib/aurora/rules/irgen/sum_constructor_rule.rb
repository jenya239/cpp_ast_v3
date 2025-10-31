# frozen_string_literal: true

require_relative "../../rules/base_rule"

module Aurora
  module Rules
    module IRGen
      class SumConstructorRule < BaseRule
        def applies?(type_decl, context = {})
          type = context[:type]
          register = context[:register_sum_type_constructors]
          type.is_a?(Aurora::CoreIR::SumType) && register
        end

        def apply(type_decl, context = {})
          register = context[:register_sum_type_constructors]
          type = context[:type]
          register.call(type_decl.name, type)
        end
      end
    end
  end
end
