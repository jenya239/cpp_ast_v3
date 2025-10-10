# frozen_string_literal: true

module CppAst
  module Nodes
    # Base node - все nodes наследуются от него
    class Node
      def to_source
        raise NotImplementedError, "#{self.class} must implement #to_source"
      end
      
      def ==(other)
        return false unless other.is_a?(self.class)
        instance_variables.all? do |var|
          instance_variable_get(var) == other.instance_variable_get(var)
        end
      end
    end
    
    # Expression - БЕЗ trivia (контролируется parent)
    class Expression < Node
      # Expressions не имеют leading_trivia
      # Parent управляет spacing
    end
    
    # Statement - С leading trivia (индентация перед statement)
    class Statement < Node
      attr_accessor :leading_trivia
      
      def initialize(leading_trivia: "")
        @leading_trivia = leading_trivia
      end
    end
  end
end

