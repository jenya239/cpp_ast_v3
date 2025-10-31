# frozen_string_literal: true

require_relative '../test_helper'

class StdlibScannerTest < Minitest::Test
  def test_scan_math_module
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    math = scanner.module_info('Math')
    refute_nil math, "Math module should be found"

    assert_equal 'Math', math.name
    assert_equal 'aurora::math', math.namespace
    assert math.file_path.end_with?('math.aur')

    # Check some known functions
    assert math.functions.key?('sqrt_f')
    assert math.functions.key?('sin_f')
    assert math.functions.key?('cos_f')

    # Check function metadata
    sqrt = math.functions['sqrt_f']
    assert_equal 'sqrt_f', sqrt.name
    assert_equal 'aurora::math::sqrt_f', sqrt.qualified_name
    assert sqrt.extern?, "sqrt_f should be extern"
  end

  def test_scan_graphics_module
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    graphics = scanner.module_info('Graphics')
    refute_nil graphics, "Graphics module should be found"

    assert_equal 'Graphics', graphics.name
    assert_equal 'aurora::graphics', graphics.namespace

    # Check functions
    assert graphics.functions.key?('create_window')
    assert graphics.functions.key?('poll_event')
    assert graphics.functions.key?('is_quit_event')

    # Check types
    assert graphics.types.key?('Window')
    assert graphics.types.key?('Event')

    # Check opaque type
    window_type = graphics.types['Window']
    assert window_type.opaque?, "Window should be opaque"
    assert_equal 'aurora::graphics::Window', window_type.qualified_name

    # Check record type
    event_type = graphics.types['Event']
    refute event_type.opaque?, "Event should not be opaque"
    assert_equal 'aurora::graphics::Event', event_type.qualified_name
  end

  def test_cpp_function_name_lookup
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    # Math functions
    assert_equal 'aurora::math::sqrt_f', scanner.cpp_function_name('sqrt_f')
    assert_equal 'aurora::math::sin_f', scanner.cpp_function_name('sin_f')
    assert_equal 'aurora::math::abs', scanner.cpp_function_name('abs')

    # Graphics functions
    assert_equal 'aurora::graphics::create_window', scanner.cpp_function_name('create_window')
    assert_equal 'aurora::graphics::poll_event', scanner.cpp_function_name('poll_event')

    # IO functions
    assert_equal 'aurora::io::println', scanner.cpp_function_name('println')

    # Non-existent function
    assert_nil scanner.cpp_function_name('nonexistent_function')
  end

  def test_conv_module_special_namespace
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    conv = scanner.module_info('Conv')
    refute_nil conv

    # Conv uses 'aurora' namespace, not 'aurora::conv'
    assert_equal 'aurora', conv.namespace

    # Check function mapping
    assert_equal 'aurora::parse_i32', scanner.cpp_function_name('parse_i32')
    assert_equal 'aurora::to_string_i32', scanner.cpp_function_name('to_string_i32')
  end

  def test_io_module_preserves_case
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    io = scanner.module_info('IO')
    refute_nil io

    # IO should preserve uppercase
    assert_equal 'aurora::io', io.namespace
  end

  def test_available_modules
    scanner = MLC::StdlibScanner.new
    modules = scanner.available_modules

    assert_includes modules, 'Math'
    assert_includes modules, 'Graphics'
    assert_includes modules, 'IO'
    assert_includes modules, 'Conv'
    assert_includes modules, 'String'
  end

  def test_module_exists
    scanner = MLC::StdlibScanner.new

    assert scanner.module_exists?('Math')
    assert scanner.module_exists?('Graphics')
    refute scanner.module_exists?('NonExistentModule')
  end

  def test_module_file_path
    scanner = MLC::StdlibScanner.new

    math_path = scanner.module_file_path('Math')
    refute_nil math_path
    assert File.exist?(math_path)
    assert math_path.end_with?('math.aur')

    assert_nil scanner.module_file_path('NonExistentModule')
  end

  def test_extern_vs_regular_functions
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    math = scanner.module_info('Math')

    # sqrt_f is extern
    sqrt = math.functions['sqrt_f']
    assert sqrt.extern?

    # hypotenuse is Aurora function (not extern)
    hypotenuse = math.functions['hypotenuse']
    refute_nil hypotenuse
    refute hypotenuse.extern?, "hypotenuse should not be extern"
  end

  def test_lazy_scanning
    scanner = MLC::StdlibScanner.new

    # Before scan, no modules
    assert_empty scanner.instance_variable_get(:@modules)

    # First access triggers scan
    scanner.available_modules

    # After scan, modules loaded
    refute_empty scanner.instance_variable_get(:@modules)

    # Second access doesn't rescan
    old_modules = scanner.instance_variable_get(:@modules)
    scanner.available_modules
    assert_same old_modules, scanner.instance_variable_get(:@modules)
  end

  def test_function_has_params_and_return_type
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    math = scanner.module_info('Math')
    sqrt = math.functions['sqrt_f']

    # Check params
    assert_equal 1, sqrt.params.length
    assert_equal 'x', sqrt.params[0][:name]

    # Check return type exists
    refute_nil sqrt.return_type
  end

  def test_record_type_has_fields
    scanner = MLC::StdlibScanner.new
    scanner.scan_all

    graphics = scanner.module_info('Graphics')
    event_type = graphics.types['Event']

    refute_empty event_type.fields

    # Event should have event_type, x, y, button, keycode fields
    field_names = event_type.fields.map { |f| f[:name] }
    assert_includes field_names, 'x'
    assert_includes field_names, 'y'
    assert_includes field_names, 'button'
  end
end
