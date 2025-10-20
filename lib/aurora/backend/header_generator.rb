# frozen_string_literal: true

module Aurora
  module Backend
    # Generates C++ header (.hpp) and implementation (.cpp) files from CoreIR modules
    class HeaderGenerator
      def initialize(lowering)
        @lowering = lowering
      end

      # Generate header and implementation files
      # Returns: { header: String, implementation: String }
      def generate(module_node)
        header_guard = generate_header_guard(module_node.name)

        # Separate declarations into header and implementation
        header_items = []
        impl_items = []

        module_node.items.each do |item|
          case item
          when CoreIR::TypeDecl
            # All type declarations go in header
            header_items << item
          when CoreIR::Func
            # Function declarations go in header, definitions in implementation
            header_items << item
            impl_items << item
          end
        end

        # Generate header file
        header = generate_header(
          module_name: module_node.name,
          guard: header_guard,
          imports: module_node.imports,
          items: header_items
        )

        # Generate implementation file
        implementation = generate_implementation(
          module_name: module_node.name,
          imports: module_node.imports,
          items: impl_items
        )

        { header: header, implementation: implementation }
      end

      private

      def generate_header_guard(module_name)
        # Convert Math::Vector -> MATH_VECTOR_HPP
        module_name.upcase.gsub("::", "_").gsub("/", "_") + "_HPP"
      end

      def generate_header(module_name:, guard:, imports:, items:)
        lines = []

        # Header guard
        lines << "#ifndef #{guard}"
        lines << "#define #{guard}"
        lines << ""

        # Standard includes
        lines << "#include <variant>"
        lines << "#include <string>"
        lines << ""

        # Module imports -> #include statements
        imports.each do |import|
          header_name = module_path_to_header(import.path)
          lines << "#include \"#{header_name}\""
        end
        lines << "" unless imports.empty?

        # Namespace for module
        namespace = module_name_to_namespace(module_name)
        unless namespace.empty?
          lines << "namespace #{namespace} {"
          lines << ""
        end

        # Generate forward declarations and type definitions
        items.each do |item|
          case item
          when CoreIR::TypeDecl
            # Full type definition goes in header
            cpp_ast = @lowering.lower(item)
            lines << cpp_ast.to_source
            lines << ""
          when CoreIR::Func
            # Only function declaration (prototype) goes in header
            func_decl = generate_function_declaration(item)
            lines << func_decl
            lines << ""
          end
        end

        # Close namespace
        unless namespace.empty?
          lines << "} // namespace #{namespace}"
          lines << ""
        end

        # Close header guard
        lines << "#endif // #{guard}"
        lines << ""

        lines.join("\n")
      end

      def generate_implementation(module_name:, imports:, items:)
        lines = []

        # Include own header
        header_name = module_path_to_header(module_name)
        lines << "#include \"#{header_name}\""
        lines << ""

        # Additional includes for implementation
        imports.each do |import|
          header_name = module_path_to_header(import.path)
          lines << "#include \"#{header_name}\""
        end
        lines << "" unless imports.empty?

        # Namespace for module
        namespace = module_name_to_namespace(module_name)
        unless namespace.empty?
          lines << "namespace #{namespace} {"
          lines << ""
        end

        # Generate function implementations
        items.each do |item|
          case item
          when CoreIR::Func
            func_impl = generate_function_implementation(item)
            lines << func_impl
            lines << ""
          end
        end

        # Close namespace
        unless namespace.empty?
          lines << "} // namespace #{namespace}"
          lines << ""
        end

        lines.join("\n")
      end

      def generate_function_declaration(func)
        ret_type = @lowering.send(:map_type, func.ret_type)
        name = func.name
        params = func.params.map do |param|
          type = @lowering.send(:map_type, param.type)
          "#{type} #{param.name}"
        end.join(", ")

        # Add template parameters if generic
        lines = []
        type_params = func.type_params || []

        unless type_params.empty?
          lines.concat(build_template_lines(type_params))
        end

        lines << "#{ret_type} #{name}(#{params});"
        lines.join("\n")
      end

      def generate_function_implementation(func)
        # Generate full function definition
        cpp_ast = @lowering.lower(func)
        cpp_ast.to_source
      end

      def module_path_to_header(path)
        # Handle three cases:
        # 1. File path: "./math" -> "math.hpp"
        # 2. File path: "../core/utils" -> "../core/utils.hpp"
        # 3. Module name: "Math::Vector" -> "math/vector.hpp"

        if path.start_with?("./", "../", "/")
          # It's a file path - just add .hpp if needed
          path.end_with?(".hpp") ? path : path + ".hpp"
        elsif path.include?("::")
          # Module path: Math::Vector -> math/vector.hpp
          path.split("::").map(&:downcase).join("/") + ".hpp"
        else
          # Simple name: Math -> math.hpp
          path.downcase + ".hpp"
        end
      end

      def module_name_to_namespace(name)
        # Convert Math::Vector -> math::vector
        name.gsub("/", "::").split("::").map(&:downcase).join("::")
      end

      def build_template_lines(type_params)
        template_params = type_params.map { |tp| "typename #{tp.name}" }.join(", ")
        requires_clause = build_requires_clause(type_params)
        lines = ["template<#{template_params}>"]
        lines << "requires #{requires_clause}" unless requires_clause.empty?
        lines
      end

      def build_requires_clause(type_params)
        clauses = type_params.map do |tp|
          next unless tp.constraint && !tp.constraint.empty?
          "#{tp.constraint}<#{tp.name}>"
        end.compact
        clauses.join(" && ")
      end
    end
  end
end
