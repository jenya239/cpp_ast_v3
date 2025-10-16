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
    
    # Type reference node
    class TypeReference < Node
      attr_reader :name, :is_const, :is_reference, :is_mutable
      
      def initialize(name:, is_const: false, is_reference: false, is_mutable: false)
        @name = name
        @is_const = is_const
        @is_reference = is_reference
        @is_mutable = is_mutable
      end
      
      def to_source
        result = @name
        result = "const #{result}" if @is_const
        result = "#{result}&" if @is_reference
        result
      end
    end
    
    # Concept parameter node
    class ConceptParameter < Node
      attr_reader :name, :constraints
      
      def initialize(name:, constraints: [])
        @name = name
        @constraints = constraints
      end
      
      def to_source
        if constraints.empty?
          name
        else
          "#{name} : #{constraints.join(' && ')}"
        end
      end
    end
    
    # Type alias node
    class TypeAlias < Node
      attr_reader :name, :type
      
      def initialize(name:, type:)
        @name = name
        @type = type
      end
      
      def to_source
        "using #{name} = #{type.to_source};"
      end
    end
    
    # Requires clause node
    class RequiresClause < Node
      attr_reader :constraints
      
      def initialize(constraints: [])
        @constraints = constraints
      end
      
      def to_source
        "requires #{constraints.join(' && ')}"
      end
    end
    
    # Template parameter node
    class TemplateParameter < Node
      attr_reader :name, :type, :default_value
      
      def initialize(name:, type: nil, default_value: nil)
        @name = name
        @type = type
        @default_value = default_value
      end
      
      def to_source
        result = name.to_s
        result += " : #{type.to_source}" if type
        result += " = #{default_value.to_source}" if default_value
        result
      end
    end
    
  end
end

