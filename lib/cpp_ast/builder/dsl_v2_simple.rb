# frozen_string_literal: true

require_relative "dsl_v2_improved"

module CppAst
  module Builder
    module DSLv2
      # Use improved DSL v2 implementation
      extend DSLv2Improved
    end
  end
end
