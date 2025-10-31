# frozen_string_literal: true

module Aurora
  module Backend
    class CodeGen
      # TypeLowerer
      # Type declaration lowering to C++
      # Auto-extracted from cpp_lowering.rb during refactoring
      module TypeLowerer
      def lower_type_decl(type_decl)
              result = case type_decl.type
                       when CoreIR::RecordType
                         lower_record_type(type_decl.name, type_decl.type)
                       when CoreIR::SumType
                         lower_sum_type(type_decl.name, type_decl.type, type_decl.type_params)
                      else
                        # For primitive types, generate empty program (no direct C++ emission)
                        CppAst::Nodes::Program.new(statements: [], statement_trailings: [])
                      end
      
              if type_decl.type_params.any?
                if result.is_a?(CppAst::Nodes::Program)
                  wrap_statements_with_template(type_decl.type_params, result)
                else
                  template_params_str, params_suffix = build_template_signature(type_decl.type_params)
                  CppAst::Nodes::TemplateDeclaration.new(
                    template_params: template_params_str,
                    declaration: result,
                    template_suffix: "",
                    less_suffix: "",
                    params_suffix: params_suffix
                  )
                end
              else
                result
              end
            end

      def lower_record_type(name, record_type)
              # Generate struct declaration
              members = record_type.fields.map do |field|
                field_type = map_type(field[:type])
                CppAst::Nodes::VariableDeclaration.new(
                  type: field_type,
                  declarators: [sanitize_identifier(field[:name])],
                  declarator_separators: [],
                  type_suffix: " ",
                  prefix_modifiers: ""
                )
              end
      
              CppAst::Nodes::StructDeclaration.new(
                name: name,
                members: members,
                member_trailings: Array.new(members.size, ""),
                struct_suffix: " ",
                name_suffix: " ",
                lbrace_suffix: "",
                rbrace_suffix: "",
                base_classes_text: ""
              )
            end

      def lower_sum_type(name, sum_type, type_params = [])
              # Generate structs for each variant
              variant_structs = sum_type.variants.map do |variant|
                if variant[:fields].empty?
                  # Empty variant - generate empty struct
                  CppAst::Nodes::StructDeclaration.new(
                    name: variant[:name],
                    members: [],
                    member_trailings: [],
                    struct_suffix: " ",
                    name_suffix: " ",
                    lbrace_suffix: "",
                    rbrace_suffix: "",
                    base_classes_text: ""
                  )
                else
                  # Variant with fields
                  members = variant[:fields].map do |field|
                    field_type = map_type(field[:type])
                    CppAst::Nodes::VariableDeclaration.new(
                      type: field_type,
                      declarators: [field[:name]],
                      declarator_separators: [],
                      type_suffix: " ",
                      prefix_modifiers: ""
                    )
                  end
      
                  CppAst::Nodes::StructDeclaration.new(
                    name: variant[:name],
                    members: members,
                    member_trailings: Array.new(members.size, ""),
                    struct_suffix: " ",
                    name_suffix: " ",
                    lbrace_suffix: "",
                    rbrace_suffix: "",
                    base_classes_text: ""
                  )
                end
              end
      
              # Generate using declaration for std::variant
              # If type has generic parameters, add them to each variant name
              variant_type_names = if type_params.any?
                                     type_params_str = type_params.map { |tp| tp.name }.join(", ")
                                     sum_type.variants.map { |v| "#{v[:name]}<#{type_params_str}>" }.join(", ")
                                   else
                                     sum_type.variants.map { |v| v[:name] }.join(", ")
                                   end
              using_decl = CppAst::Nodes::UsingDeclaration.new(
                kind: :alias,
                name: name,
                alias_target: "std::variant<#{variant_type_names}>",
                using_suffix: " ",
                equals_prefix: " ",
                equals_suffix: " "
              )
      
              # Return program with all structs + using declaration
              all_statements = variant_structs + [using_decl]
              CppAst::Nodes::Program.new(
                statements: all_statements,
                statement_trailings: Array.new(all_statements.size, "")
              )
            end

      end
    end
  end
end
