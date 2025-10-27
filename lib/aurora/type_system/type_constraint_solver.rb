# frozen_string_literal: true

module Aurora
  module TypeSystem
    class TypeConstraintSolver
      Instantiation = Struct.new(:type_map, :param_types, :ret_type)

      def initialize(infer_type_arguments:, substitute_type:, ensure_compatible_type:, type_error:)
        @infer_type_arguments = infer_type_arguments
        @substitute_type = substitute_type
        @ensure_compatible_type = ensure_compatible_type
        @type_error = type_error
      end

      def solve(info, args, name:)
        type_params = info.type_params || []
        arg_types = args.map(&:type)
        type_map = @infer_type_arguments.call(type_params, info.param_types, arg_types)

        param_types = info.param_types.map { |pt| @substitute_type.call(pt, type_map) }

        if param_types.length != args.length
          @type_error.call("Function '#{name}' expects #{param_types.length} argument(s), got #{args.length}")
        end

        param_types.each_with_index do |type, index|
          @ensure_compatible_type.call(
            args[index].type,
            type,
            "argument #{index + 1} of '#{name}'"
          )
        end

        ret_type = @substitute_type.call(info.ret_type, type_map)

        Instantiation.new(type_map, param_types, ret_type)
      end
    end
  end
end
