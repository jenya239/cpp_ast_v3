# frozen_string_literal: true

module Aurora
  module Passes
    class ToCore
      # TypeContext centralizes type-related stacked state.
      class TypeContext
        attr_reader :type_param_stack, :lambda_param_stack, :function_return_stack

        def initialize
          @type_param_stack = []
          @lambda_param_stack = []
          @function_return_stack = []
        end

        def with_type_params(params)
          @type_param_stack.push(params || [])
          yield
        ensure
          @type_param_stack.pop
        end

        def current_type_params
          @type_param_stack.last || []
        end

        def with_function_return(type)
          @function_return_stack.push(type)
          yield
        ensure
          @function_return_stack.pop
        end

        def current_function_return
          @function_return_stack.last
        end

        def with_lambda_param_types(types)
          @lambda_param_stack.push(Array(types))
          yield
        ensure
          @lambda_param_stack.pop
        end

        def current_lambda_param_types
          @lambda_param_stack.last || []
        end
      end
    end
  end
end
