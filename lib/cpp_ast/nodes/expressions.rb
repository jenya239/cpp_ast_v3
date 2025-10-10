# frozen_string_literal: true

module CppAst
  module Nodes
    # Identifier - простейший expression
    class Identifier < Expression
      attr_accessor :name
      
      def initialize(name:)
        @name = name
      end
      
      def to_source
        name
      end
    end
    
    # NumberLiteral
    class NumberLiteral < Expression
      attr_accessor :value
      
      def initialize(value:)
        @value = value
      end
      
      def to_source
        value
      end
    end
    
    # BinaryExpression - binary operators like +, -, *, /, =, etc
    class BinaryExpression < Expression
      attr_accessor :left, :operator, :right, :operator_prefix, :operator_suffix
      
      def initialize(left:, operator:, right:, operator_prefix: "", operator_suffix: "")
        @left = left
        @operator = operator
        @right = right
        @operator_prefix = operator_prefix
        @operator_suffix = operator_suffix
      end
      
      def to_source
        "#{left.to_source}#{operator_prefix}#{operator}#{operator_suffix}#{right.to_source}"
      end
    end
    
    # UnaryExpression - unary operators like !, ++, --, -, +
    class UnaryExpression < Expression
      attr_accessor :operator, :operand, :operator_suffix, :prefix
      
      def initialize(operator:, operand:, operator_suffix: "", prefix: true)
        @operator = operator
        @operand = operand
        @operator_suffix = operator_suffix
        @prefix = prefix
      end
      
      def to_source
        if prefix
          "#{operator}#{operator_suffix}#{operand.to_source}"
        else
          "#{operand.to_source}#{operator}"
        end
      end
    end
  end
end

