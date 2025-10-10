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
    
    # StringLiteral
    class StringLiteral < Expression
      attr_accessor :value
      
      def initialize(value:)
        @value = value
      end
      
      def to_source
        value
      end
    end
    
    # CharLiteral
    class CharLiteral < Expression
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
    
    # ParenthesizedExpression - expressions wrapped in parentheses
    class ParenthesizedExpression < Expression
      attr_accessor :expression, :open_paren_suffix, :close_paren_prefix
      
      def initialize(expression:, open_paren_suffix: "", close_paren_prefix: "")
        @expression = expression
        @open_paren_suffix = open_paren_suffix
        @close_paren_prefix = close_paren_prefix
      end
      
      def to_source
        "(#{open_paren_suffix}#{expression.to_source}#{close_paren_prefix})"
      end
    end
    
    # FunctionCallExpression - function call: foo(arg1, arg2)
    class FunctionCallExpression < Expression
      attr_accessor :callee, :arguments, :argument_separators, :lparen_suffix, :rparen_prefix
      
      def initialize(callee:, arguments:, argument_separators: [], lparen_suffix: "", rparen_prefix: "")
        @callee = callee
        @arguments = arguments
        @argument_separators = argument_separators
        @lparen_suffix = lparen_suffix
        @rparen_prefix = rparen_prefix
      end
      
      def to_source
        result = "#{callee.to_source}(#{lparen_suffix}"
        
        arguments.each_with_index do |arg, i|
          result << arg.to_source
          
          # Add separator (comma) after each arg except the last
          if i < arguments.length - 1
            separator = argument_separators[i] || ","
            result << separator
          end
        end
        
        result << "#{rparen_prefix})"
        result
      end
    end
    
    # MemberAccessExpression - member access: obj.field, ptr->field, Class::member
    class MemberAccessExpression < Expression
      attr_accessor :object, :operator, :member, :operator_prefix, :operator_suffix
      
      def initialize(object:, operator:, member:, operator_prefix: "", operator_suffix: "")
        @object = object
        @operator = operator
        @member = member
        @operator_prefix = operator_prefix
        @operator_suffix = operator_suffix
      end
      
      def to_source
        "#{object.to_source}#{operator_prefix}#{operator}#{operator_suffix}#{member.to_source}"
      end
    end
    
    # ArraySubscriptExpression - array subscript: arr[index]
    class ArraySubscriptExpression < Expression
      attr_accessor :array, :index, :lbracket_suffix, :rbracket_prefix
      
      def initialize(array:, index:, lbracket_suffix: "", rbracket_prefix: "")
        @array = array
        @index = index
        @lbracket_suffix = lbracket_suffix
        @rbracket_prefix = rbracket_prefix
      end
      
      def to_source
        "#{array.to_source}[#{lbracket_suffix}#{index.to_source}#{rbracket_prefix}]"
      end
    end
    
    # TernaryExpression - ternary operator: condition ? true : false
    class TernaryExpression < Expression
      attr_accessor :condition, :true_expression, :false_expression
      attr_accessor :question_prefix, :question_suffix, :colon_prefix, :colon_suffix
      
      def initialize(condition:, true_expression:, false_expression:,
                     question_prefix: "", question_suffix: "",
                     colon_prefix: "", colon_suffix: "")
        @condition = condition
        @true_expression = true_expression
        @false_expression = false_expression
        @question_prefix = question_prefix
        @question_suffix = question_suffix
        @colon_prefix = colon_prefix
        @colon_suffix = colon_suffix
      end
      
      def to_source
        "#{condition.to_source}#{question_prefix}?#{question_suffix}" \
        "#{true_expression.to_source}#{colon_prefix}:#{colon_suffix}" \
        "#{false_expression.to_source}"
      end
    end
  end
end

