# frozen_string_literal: true

require_relative "base_pass"

module Aurora
  module Analysis
    # NameResolutionPass - builds symbol table and resolves all names
    # This is a simplified initial version that demonstrates the pass pattern.
    #
    # Results stored in:
    #   context[:symbol_table] = { name => { kind: :function/:variable/:type, decl: node } }
    #   context[:resolution_errors] = [error_messages]
    #
    # TODO: Fully implement name resolution with scoping and reference checking
    class NameResolutionPass < BasePass
      def initialize(name: "name_resolution")
        super(name: name)
      end

      def run(context)
        core_ir = context[:core_ir]
        return unless core_ir

        @symbol_table = {}
        @errors = []

        # Collect all top-level declarations
        core_ir.items.each do |item|
          case item
          when CoreIR::Func
            if @symbol_table.key?(item.name)
              @errors << "Duplicate function declaration: #{item.name}"
            else
              @symbol_table[item.name] = {
                kind: :function,
                decl: item,
                type: item.ret_type
              }
            end
          when CoreIR::TypeDecl
            name = item.name
            if @symbol_table.key?(name)
              @errors << "Name conflict: '#{name}' is already declared"
            else
              @symbol_table[name] = {
                kind: :type,
                decl: item
              }
            end
          end
        end

        # Store results in context
        context[:symbol_table] = @symbol_table
        context[:resolution_errors] = @errors
        context[:name_resolution_passed] = @errors.empty?
      end
    end
  end
end
