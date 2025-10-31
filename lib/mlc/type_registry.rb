# frozen_string_literal: true

module MLC
  # TypeRegistry - Unified type system management
  #
  # Single source of truth for all type information:
  # - Type definitions (AST and HighIR)
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
    attr_reader :name, :ast_node, :core_ir_type, :cpp_name, :namespace, :kind, :exported, :module_name
    attr_accessor :fields, :variants

    # @param name [String] Type name in Aurora (e.g., "Event", "Window")
    # @param ast_node [AST::TypeDecl, nil] Original AST node
    # @param core_ir_type [HighIR::Type] Transformed HighIR type
    # @param namespace [String, nil] C++ namespace (e.g., "mlc::graphics")
    # @param kind [Symbol] :primitive, :record, :sum, :opaque, :function, :array
    # @param exported [Boolean] Is this type exported from module?
    def initialize(name:, ast_node: nil, core_ir_type:, namespace: nil, kind:, exported: false, module_name: nil)
      @name = name
      @ast_node = ast_node
      @core_ir_type = core_ir_type
      @namespace = namespace
      @kind = kind
      @exported = exported
      @module_name = module_name

      # Cache fields/variants for faster access
      @fields = extract_fields(core_ir_type)
      @variants = extract_variants(core_ir_type)
      @referenced_type_names = extract_referenced_type_names(core_ir_type)

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

    def referenced_type_names
      @referenced_type_names
    end

    def referenced_module_names(type_registry, include_self: false)
      return [] unless type_registry

      referenced_type_names.each_with_object([]) do |type_name, acc|
        next if type_name == name && !include_self
        info = type_registry.lookup(type_name)
        next unless info
        acc << info.module_name if info.module_name && !info.module_name.empty?
      end.uniq
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

    def extract_referenced_type_names(type)
      names = []
      collect_type_names(type, names)
      names.delete(name)
      names.uniq
    end

    def collect_type_names(type, names)
      return unless type

      case type
      when HighIR::GenericType
        collect_type_names(type.base_type, names)
        type.type_args.each { |arg| collect_type_names(arg, names) }
      when HighIR::ArrayType
        collect_type_names(type.element_type, names)
      when HighIR::FunctionType
        type.params.each { |param| collect_type_names(param[:type], names) }
        collect_type_names(type.ret_type, names)
      when HighIR::RecordType
        type.fields.each do |field|
          collect_type_names(field[:type], names)
        end
      when HighIR::SumType
        type.variants.each do |variant|
          Array(variant[:fields]).each do |field|
            collect_type_names(field[:type], names)
          end
        end
      when HighIR::TypeVariable
        # ignore
      when HighIR::Type
        names << type.name if type.name
      end
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
      'bool' => 'bool',
      'void' => 'void',
      'unit' => 'void',          # Unit type maps to void in C++
      'i8' => 'int8_t',
      'u8' => 'uint8_t',
      'i16' => 'int16_t',
      'u16' => 'uint16_t',
      'i32' => 'int',
      'u32' => 'uint32_t',
      'i64' => 'int64_t',
      'u64' => 'uint64_t',
      'f32' => 'float',
      'f64' => 'double',
      'usize' => 'size_t',
      'str' => 'mlc::String',
      'string' => 'mlc::String',
      'regex' => 'mlc::Regex'
    }.freeze
  end

  class TypeRegistry
    attr_reader :types

    def initialize
      @types = {}  # name => TypeInfo
      @namespaces = {}  # namespace => [type_names]
      # module_name => [type_names]
      @modules = Hash.new { |hash, key| hash[key] = [] }

      # Register built-in primitive types
      register_primitives
    end

    # Register a type in the registry
    # @param name [String] Type name
    # @param ast_node [AST::TypeDecl, nil] Original AST
    # @param core_ir_type [HighIR::Type] Transformed type
    # @param namespace [String, nil] C++ namespace
    # @param kind [Symbol] Type kind
    # @param exported [Boolean] Is exported?
    def register(name, ast_node: nil, core_ir_type:, namespace: nil, kind:, exported: false, module_name: nil)
      type_info = TypeInfo.new(
        name: name,
        ast_node: ast_node,
        core_ir_type: core_ir_type,
        namespace: namespace,
        kind: kind,
        exported: exported,
        module_name: module_name
      )

      previous = @types[name]
      remove_from_module_index(previous.module_name, name) if previous&.module_name && previous.module_name != module_name

      @types[name] = type_info

      # Track namespace membership
      if namespace
        @namespaces[namespace] ||= []
        @namespaces[namespace] << name unless @namespaces[namespace].include?(name)
      end

      track_module_membership(module_name, name)

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
    # @return [HighIR::Type, nil] Type of the member
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

    # Get all types defined in a module
    # @param module_name [String]
    # @return [Array<TypeInfo>]
    def types_in_module(module_name, exported_only: false)
      return [] if module_name.nil? || module_name.empty?
      names = @modules[module_name]
      return [] unless names

      result = names.filter_map { |name| @types[name] }
      exported_only ? result.select(&:exported) : result
    end

    # Convenience helper returning only exported types for a module.
    # @param module_name [String]
    # @return [Array<TypeInfo>]
    def exported_types_in_module(module_name)
      types_in_module(module_name, exported_only: true)
    end

    def module_name_for(type_name)
      @types[type_name]&.module_name
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
      @modules.clear
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
        prim_type = HighIR::Type.new(kind: :prim, name: aurora_name)
        register(
          aurora_name,
          core_ir_type: prim_type,
          kind: :primitive,
          exported: false
        )
      end
    end

    def track_module_membership(module_name, type_name)
      return if module_name.nil? || module_name.empty?

      members = @modules[module_name]
      members << type_name unless members.include?(type_name)
    end

    def remove_from_module_index(module_name, type_name)
      return if module_name.nil? || module_name.empty?

      members = @modules[module_name]
      members.delete(type_name)
      @modules.delete(module_name) if members.empty?
    end
  end
end
