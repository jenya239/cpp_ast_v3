# frozen_string_literal: true

module CppAst
  module Nodes
    # Sum type declaration - generates struct + variant
    class SumTypeDeclaration < Statement
      attr_accessor :name, :cases, :case_trailings
      attr_accessor :sum_suffix, :name_suffix, :lbrace_suffix, :rbrace_suffix

      def initialize(leading_trivia: "", name:, cases:, case_trailings: [],
                     sum_suffix: " ", name_suffix: " ", lbrace_suffix: "\n", rbrace_suffix: "\n")
        super(leading_trivia: leading_trivia)
        @name = name
        @cases = cases
        @case_trailings = case_trailings
        @sum_suffix = sum_suffix
        @name_suffix = name_suffix
        @lbrace_suffix = lbrace_suffix
        @rbrace_suffix = rbrace_suffix
      end

      def to_source
        result = "#{leading_trivia}"
        
        # Generate struct declarations for each case
        cases.each_with_index do |case_node, i|
          result << case_node.to_source
          result << case_trailings[i] if i < case_trailings.length
        end
        
        # Generate variant alias
        case_names = cases.map(&:name)
        variant_types = case_names.join(", ")
        result << "using #{name} = std::variant<#{variant_types}>;"
        
        result
      end
    end

    # Variant case - generates struct for one case
    class VariantCase < Statement
      attr_accessor :name, :fields, :field_trailings
      attr_accessor :struct_suffix, :name_suffix, :lbrace_suffix, :rbrace_suffix

      def initialize(leading_trivia: "", name:, fields:, field_trailings: [],
                     struct_suffix: " ", name_suffix: " ", lbrace_suffix: "\n", rbrace_suffix: "\n")
        super(leading_trivia: leading_trivia)
        @name = name
        @fields = fields
        @field_trailings = field_trailings
        @struct_suffix = struct_suffix
        @name_suffix = name_suffix
        @lbrace_suffix = lbrace_suffix
        @rbrace_suffix = rbrace_suffix
      end

      def to_source
        result = "#{leading_trivia}struct#{struct_suffix}#{name}#{name_suffix}{#{lbrace_suffix}"
        
        fields.zip(field_trailings).each do |field, trailing|
          if field.is_a?(Array) && field.length == 2
            # Handle field_def format: [name, type]
            field_str = "#{field[1]} #{field[0]};"
          else
            field_str = field.respond_to?(:to_source) ? field.to_source : field.to_s
          end
          result << field_str << trailing
        end
        
        result << "#{rbrace_suffix}};"
        result
      end
    end
  end
end
