# frozen_string_literal: true

require "set"

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
        dependencies = collect_required_import_paths(module_node)

        # Separate declarations into header and implementation
        header_items = []
        impl_items = []

        module_node.items.each do |item|
          case item
          when CoreIR::TypeDecl
            # All type declarations go in header
            header_items << item
          when CoreIR::Func
            # Function declarations go in header
            header_items << item
            # External functions don't need implementation
            impl_items << item unless item.external
          end
        end

        # Generate header file
        header = generate_header(
          module_name: module_node.name,
          guard: header_guard,
          imports: module_node.imports,
          items: header_items,
          dependencies: dependencies
        )

        # Generate implementation file
        implementation = generate_implementation(
          module_name: module_node.name,
          imports: module_node.imports,
          items: impl_items,
          required_imports: dependencies[:implementation]
        )

        { header: header, implementation: implementation }
      end

      private

      def generate_header_guard(module_name)
        # Convert Math::Vector -> MATH_VECTOR_HPP
        module_name.upcase.gsub("::", "_").gsub("/", "_") + "_HPP"
      end

      def generate_header(module_name:, guard:, imports:, items:, dependencies:)
        lines = []

        # Header guard
        lines << "#ifndef #{guard}"
        lines << "#define #{guard}"
        lines << ""

        # Standard includes
        lines << "#include <variant>"
        lines << "#include <string>"
        lines << "#include \"aurora_match.hpp\""
        lines << ""

        # Module imports -> #include statements
        header_imports = filtered_imports(imports, dependencies[:header])
        header_imports.each do |import|
          header_name = module_path_to_header(import.path)
          lines << "#include \"#{header_name}\""
        end
        lines << "" unless header_imports.empty?

        forward_decls = build_forward_declarations(module_name, items, dependencies)
        unless forward_decls.empty?
          lines.concat(forward_decls)
          lines << ""
        end

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

      def generate_implementation(module_name:, imports:, items:, required_imports:)
        lines = []

        # Include own header
        header_name = module_path_to_header(module_name)
        lines << "#include \"#{header_name}\""
        lines << ""

        # Additional includes for implementation
        impl_imports = filtered_imports(imports, required_imports)
        impl_imports.each do |import|
          header_name = module_path_to_header(import.path)
          lines << "#include \"#{header_name}\""
        end
        lines << "" unless impl_imports.empty?

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

      def filtered_imports(imports, required_imports)
        return imports if required_imports.nil? || required_imports.empty?
        imports.select { |import| include_import?(import, required_imports) }
      end

      def include_import?(import, required_imports)
        path = import.path
        return true if path.start_with?("./", "../", "/")
        required_imports.include?(path)
      end

      def generate_function_declaration(func)
        ret_type = @lowering.send(:map_type, func.ret_type)
        name = @lowering.send(:sanitize_identifier, func.name)
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

      def collect_required_import_paths(module_node)
        registry = @lowering.respond_to?(:function_registry) ? @lowering.function_registry : nil
        empty_result = { header: Set.new, implementation: Set.new, forward: Set.new }
        return empty_result unless registry

        @include_modules = Set.new
        @forward_modules = Set.new
        current_module = module_node.name

        module_node.items.each do |item|
          case item
          when Aurora::CoreIR::Func
            next unless item.body
            collect_modules_from_type(item.ret_type, current_module, require_include: true)
            item.params.each { |param| collect_modules_from_type(param.type, current_module, require_include: true) }
            collect_modules_from_expr(item.body, registry, current_module)
          when Aurora::CoreIR::TypeDecl
            type_info = @lowering.type_registry&.lookup(item.name)
            if type_info
              type_info.referenced_type_names.each do |type_name|
                module_name = @lowering.type_registry.module_name_for(type_name)
                mark_module_dependency(module_name, current_module, require_include: true)
              end
            end
          end
        end

        {
          header: @include_modules.dup,
          implementation: (@include_modules | @forward_modules),
          forward: @forward_modules.dup
        }
      ensure
        @include_modules = nil
        @forward_modules = nil
      end

      def build_forward_declarations(current_module, items, dependencies)
        type_registry = @lowering.type_registry
        return [] unless type_registry

        include_modules = dependencies[:header] || Set.new
        forward_modules = dependencies[:forward] || Set.new
        forward_lines = []
        seen = Set.new

        items.each do |item|
          next unless item.is_a?(Aurora::CoreIR::TypeDecl)
          info = type_registry.lookup(item.name)
          next unless info

          info.referenced_type_names.each do |type_name|
            next if seen.include?(type_name)
            referenced_module = type_registry.module_name_for(type_name)
            next unless referenced_module
            next if referenced_module == current_module
            next if include_modules.include?(referenced_module)
            next unless forward_modules.include?(referenced_module)

            decl = forward_declaration_for(type_registry.lookup(type_name))
            next unless decl

            forward_lines << decl
            seen << type_name
          end
        end

        forward_lines
      end

      def forward_declaration_for(type_info)
        return nil unless type_info

        case type_info.kind
        when :record, :sum
          "struct #{type_info.name};"
        else
          nil
        end
      end

      def collect_modules_from_expr(expr, registry, current_module)
        return unless expr

        case expr
        when Aurora::CoreIR::CallExpr
          if expr.callee.is_a?(Aurora::CoreIR::VarExpr)
            entry = registry.fetch_entry(expr.callee.name)
            mark_module_dependency(entry&.module_name, current_module, require_include: true)
          else
            collect_modules_from_expr(expr.callee, registry, current_module)
          end
          expr.args.each { |arg| collect_modules_from_expr(arg, registry, current_module) }
        when Aurora::CoreIR::BinaryExpr
          collect_modules_from_expr(expr.left, registry, current_module)
          collect_modules_from_expr(expr.right, registry, current_module)
        when Aurora::CoreIR::UnaryExpr
          collect_modules_from_expr(expr.operand, registry, current_module)
        when Aurora::CoreIR::MemberExpr
          collect_modules_from_expr(expr.object, registry, current_module)
        when Aurora::CoreIR::IndexExpr
          collect_modules_from_expr(expr.object, registry, current_module)
          collect_modules_from_expr(expr.index, registry, current_module)
        when Aurora::CoreIR::RecordExpr
          expr.fields.each_value { |value| collect_modules_from_expr(value, registry, current_module) }
          collect_modules_from_type(expr.type, current_module, require_include: true)
        when Aurora::CoreIR::IfExpr
          collect_modules_from_expr(expr.condition, registry, current_module)
          collect_modules_from_expr(expr.then_branch, registry, current_module)
          collect_modules_from_expr(expr.else_branch, registry, current_module) if expr.else_branch
        when Aurora::CoreIR::MatchExpr
          collect_modules_from_expr(expr.scrutinee, registry, current_module)
          expr.arms.each do |arm|
            collect_modules_from_expr(arm[:guard], registry, current_module) if arm[:guard]
            collect_modules_from_expr(arm[:body], registry, current_module)
          end
        when Aurora::CoreIR::LambdaExpr
          collect_modules_from_expr(expr.body, registry, current_module)
        when Aurora::CoreIR::BlockExpr
          expr.statements.each { |stmt| collect_modules_from_statement(stmt, registry, current_module) }
          collect_modules_from_expr(expr.result, registry, current_module) if expr.result
        when Aurora::CoreIR::ArrayLiteralExpr
          expr.elements.each { |element| collect_modules_from_expr(element, registry, current_module) }
          collect_modules_from_type(expr.type, current_module)
        when Aurora::CoreIR::ListCompExpr
          Array(expr.generators).each do |gen|
            if gen.respond_to?(:[]) && gen[:iterable]
              collect_modules_from_expr(gen[:iterable], registry, current_module)
            end
            if gen.respond_to?(:[]) && gen[:body]
              collect_modules_from_expr(gen[:body], registry, current_module)
            end
          end
          Array(expr.filters).each { |filter| collect_modules_from_expr(filter, registry, current_module) }
          collect_modules_from_expr(expr.output_expr, registry, current_module)
        when Aurora::CoreIR::Block
          expr.stmts.each { |stmt| collect_modules_from_statement(stmt, registry, current_module) }
        when Aurora::CoreIR::VarExpr, Aurora::CoreIR::LiteralExpr, Aurora::CoreIR::UnitLiteral, Aurora::CoreIR::RegexExpr
          # no-op
        else
          collect_modules_from_type(expr.type, current_module) if expr.respond_to?(:type)
        end
      end

      def collect_modules_from_statement(stmt, registry, current_module)
        return unless stmt

        case stmt
        when Aurora::CoreIR::ExprStatement
          collect_modules_from_expr(stmt.expression, registry, current_module)
        when Aurora::CoreIR::Return
          collect_modules_from_expr(stmt.expr, registry, current_module)
        when Aurora::CoreIR::VariableDeclStmt
          collect_modules_from_expr(stmt.value, registry, current_module)
          collect_modules_from_type(stmt.type, current_module, require_include: true)
        when Aurora::CoreIR::AssignmentStmt
          collect_modules_from_expr(stmt.value, registry, current_module)
        when Aurora::CoreIR::IfStmt
          collect_modules_from_expr(stmt.condition, registry, current_module)
          collect_modules_from_statement(stmt.then_body, registry, current_module)
          collect_modules_from_statement(stmt.else_body, registry, current_module)
        when Aurora::CoreIR::ForStmt
          collect_modules_from_expr(stmt.iterable, registry, current_module)
          collect_modules_from_statement(stmt.body, registry, current_module)
        when Aurora::CoreIR::WhileStmt
          collect_modules_from_expr(stmt.condition, registry, current_module)
          collect_modules_from_statement(stmt.body, registry, current_module)
        when Aurora::CoreIR::MatchStmt
          collect_modules_from_expr(stmt.scrutinee, registry, current_module)
          stmt.arms.each do |arm|
            collect_modules_from_expr(arm[:guard], registry, current_module) if arm[:guard]
            collect_modules_from_expr(arm[:body], registry, current_module)
          end
        when Aurora::CoreIR::Block
          stmt.stmts.each { |inner| collect_modules_from_statement(inner, registry, current_module) }
        end
      end

      def collect_modules_from_type(type, current_module, require_include: false)
        return unless type

        case type
        when Aurora::CoreIR::GenericType
          collect_modules_from_type(type.base_type, current_module, require_include: require_include)
          type.type_args.each { |arg| collect_modules_from_type(arg, current_module, require_include: require_include) }
        when Aurora::CoreIR::ArrayType
          collect_modules_from_type(type.element_type, current_module, require_include: require_include)
        when Aurora::CoreIR::FunctionType
          type.params.each { |param| collect_modules_from_type(param[:type], current_module, require_include: true) }
          collect_modules_from_type(type.ret_type, current_module, require_include: true)
        when Aurora::CoreIR::RecordType, Aurora::CoreIR::SumType
          module_name = module_name_for_type(type)
          mark_module_dependency(module_name, current_module, require_include: true)
        when Aurora::CoreIR::Type
          module_name = module_name_for_type(type)
          mark_module_dependency(module_name, current_module, require_include: require_include || requires_definition?(type))
        end
      end

      def mark_module_dependency(module_name, current_module, require_include: false)
        return unless module_name
        return if module_name.empty?
        return if current_module && module_name == current_module

        if require_include
          @include_modules << module_name
          @forward_modules.delete(module_name)
        elsif !@include_modules.include?(module_name)
          @forward_modules << module_name
        end
      end

      def requires_definition?(type)
        type_info = lookup_type_info(type)
        return false unless type_info
        type_info.record? || type_info.sum?
      end

      def lookup_type_info(type)
        type_registry = @lowering.type_registry
        return nil unless type_registry

        type_name = type.respond_to?(:name) ? type.name : nil
        return nil unless type_name

        type_registry.lookup(type_name)
      end

      def module_name_for_type(type)
        lookup_type_info(type)&.module_name
      end
    end
  end
end
