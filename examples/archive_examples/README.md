# Archived Examples

This directory contains archived examples that are either duplicates, simplified variants, or obsolete development iterations.

## Archived Files

### Duplicate/Simplified Variants (moved 2025-10-17)
- `05_opengl_shader_simple.rb` - Simplified variant of 05_opengl_shader.rb
- `09_template_buffer_minimal.rb` - Minimal variant of 09_template_buffer.rb
- `09_template_buffer_simple.rb` - Simple variant of 09_template_buffer.rb
- `10_modern_cpp_basic.rb` - Basic variant of 10_modern_cpp.rb
- `10_modern_cpp_minimal.rb` - Minimal variant of 10_modern_cpp.rb
- `10_modern_cpp_simple.rb` - Simple variant of 10_modern_cpp.rb
- `11_enum_class_simple.rb` - Simple variant of 11_enum_class.rb
- `12_aurora_dsl_complete.rb` - Replaced by 12_aurora_dsl.rb (renamed from final)

### Phase Development Demos (moved 2025-10-17)
- `13_phase1_demo.rb` - Phase 1: Virtual Methods & Inheritance
- `14_dsl_generator_demo.rb` - DSL Generator demonstration
- `15_phase2_demo.rb` - Phase 2 development demo
- `16_phase3_demo.rb` - Phase 3 development demo
- `17_phase4_demo.rb` - Phase 4 development demo

All phase demos are superseded by `18_final_comprehensive_demo.rb`

### Test Files (moved 2025-10-17)
- `test_dsl_v2.rb` - Test file with broken relative imports
- `test_dsl_v2_simple.rb` - Simplified test file with broken relative imports

These test files used `require_relative "lib/cpp_ast"` which doesn't work from the examples directory.
