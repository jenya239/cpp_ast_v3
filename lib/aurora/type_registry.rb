# frozen_string_literal: true

module Aurora
  # TypeRegistry - Unified type system management
  #
  # Single source of truth for all type information:
  # - Type definitions (AST and CoreIR)
  # - C++ name mappings
  # - Namespace information
  # - Member access resolution
  # - Type compatibility checking
  #
  # Goals:
  # 1. Eliminate duplicate type storage (@type_table, @type_map, etc)
  # 2. Automatic C++ namespace qualification
  # 3. Consistent member access resolution
  # 4. Support for opaque types
  # 5. Stdlib type auto-registration

  class TypeInfo
    attr_reader :name, :ast_node, :core_ir_type, :cpp_name, :namespace, :kind, :exported
    attr_accessor :fields, :variants

    # @param name [String] Type name in Aurora (e.g., "Event", "Window")
    # @param ast_node [AST::TypeDecl, nil] Original AST node
    # @param core_ir_type [CoreIR::Type] Transformed CoreIR type
    # @param namespace [String, nil] C++ namespace (e.g., "aurora::graphics")
    # @param kind [Symbol] :primitive, :record, :sum, :opaque, :function, :array
    # @param exported [Boolean] Is this type exported from module?
    def initialize(name:, ast_node: nil, core_ir_type:, namespace: nil, kind:, exported: false)
      @name = name
      @ast_node = ast_node
      @core_ir_type = core_ir_type
      @namespace = namespace
      @kind = kind
      @exported = exported

      # Cache fields/variants for faster access
      @fields = extract_fields(core_ir_type)
      @variants = extract_variants(core_ir_type)

      # Compute C++ qualified name
      @cpp_name = compute_cpp_name(name, namespace, kind, core_ir_type)
    end

    def record?
      kind == :record
    end

    def sum?
      kind == :sum
    end

    def opaque?
      kind == :opaque
    end

    def primitive?
      kind == :primitive
    end

    def has_field?(field_name)
      @fields&.any? { |f| f[:name] == field_name }
    end

    def get_field(field_name)
      @fields&.find { |f| f[:name] == field_name }
    end

    def has_variant?(variant_name)
      @variants&.any? { |v| v[:name] == variant_name }
    end

    private

    def extract_fields(type)
      return nil unless type.respond_to?(:fields)
      type.fields
    end

    def extract_variants(type)
      return nil unless type.respond_to?(:variants)
      type.variants
    end

    def compute_cpp_name(name, namespace, kind, type)
      # Primitive types have standard C++ mappings
      if kind == :primitive
        return PRIMITIVE_TYPE_MAP[name] || name
      end

      # Opaque pointer types
      if kind == :opaque
        qualified = namespace ? "#{namespace}::#{name}" : name
        return "#{qualified}*"  # Opaque types are always pointers
      end

      # Regular types with namespace
      namespace ? "#{namespace}::#{name}" : name
    end

    # Standard primitive type mappings
    PRIMITIVE_TYPE_MAP = {
      'i32' => 'int',
      'f32' => 'float',
      'bool' => 'bool',
      'void' => 'void',
      'unit' => 'void',  # Unit type maps to void in C++
      'str' => 'aurora::String',
      'string' => 'aurora::String',
      'regex' => 'aurora::Regex'
    }.freeze
  end

  class TypeRegistry
    attr_reader :types

    def initialize
      @types = {}  # name => TypeInfo
      @namespaces = {}  # namespace => [type_names]

      # Register built-in primitive types
      register_primitives
    end

    # Register a type in the registry
    # @param name [String] Type name
    # @param ast_node [AST::TypeDecl, nil] Original AST
    # @param core_ir_type [CoreIR::Type] Transformed type
    # @param namespace [String, nil] C++ namespace
    # @param kind [Symbol] Type kind
    # @param exported [Boolean] Is exported?
    def register(name, ast_node: nil, core_ir_type:, namespace: nil, kind:, exported: false)
      type_info = TypeInfo.new(
        name: name,
        ast_node: ast_node,
        core_ir_type: core_ir_type,
        namespace: namespace,
        kind: kind,
        exported: exported
      )

      @types[name] = type_info

      # Track namespace membership
      if namespace
        @namespaces[namespace] ||= []
        @namespaces[namespace] << name unless @namespaces[namespace].include?(name)
      end

      type_info
    end

    # Lookup a type by name
    # @param name [String] Type name
    # @return [TypeInfo, nil]
    def lookup(name)
      @types[name]
    end

    # Get C++ name for a type
    # @param name [String] Aurora type name
    # @return [String] C++ qualified name
    def cpp_name(name)
      type_info = lookup(name)
      return name unless type_info
      type_info.cpp_name
    end

    # Resolve member access on a type
    # @param type_name [String] Type name
    # @param member [String] Member/field name
    # @return [CoreIR::Type, nil] Type of the member
    def resolve_member(type_name, member)
      type_info = lookup(type_name)
      return nil unless type_info

      if type_info.record?
        field = type_info.get_field(member)
        return field[:type] if field
      end

      # Could extend for methods, properties, etc.
      nil
    end

    # Check if a type exists
    # @param name [String] Type name
    # @return [Boolean]
    def has_type?(name)
      @types.key?(name)
    end

    # Get all types in a namespace
    # @param namespace [String] Namespace name
    # @return [Array<TypeInfo>]
    def types_in_namespace(namespace)
      type_names = @namespaces[namespace] || []
      type_names.map { |name| @types[name] }.compact
    end

    # Get all exported types
    # @return [Array<TypeInfo>]
    def exported_types
      @types.values.select(&:exported)
    end

    # Clear all registered types (useful for testing)
    def clear
      @types.clear
      @namespaces.clear
      register_primitives
    end

    # Debug: dump all registered types
    def dump
      @types.each do |name, info|
        puts "#{name} -> #{info.cpp_name} (#{info.kind}, ns=#{info.namespace || 'none'})"
      end
    end

    private

    def register_primitives
      # Register built-in primitive types
      TypeInfo::PRIMITIVE_TYPE_MAP.each do |aurora_name, cpp_name|
        prim_type = CoreIR::Type.new(kind: :prim, name: aurora_name)
        register(
          aurora_name,
          core_ir_type: prim_type,
          kind: :primitive,
          exported: false
        )
      end
    end
  end
end
