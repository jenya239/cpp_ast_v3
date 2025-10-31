# frozen_string_literal: true

module MLC
  module TypeSystem
    class GenericCallResolver
      def initialize(constraint_solver:)
        @constraint_solver = constraint_solver
      end

      def instantiate(info, args, name:)
        @constraint_solver.solve(info, args, name: name)
      end
    end
  end
end
