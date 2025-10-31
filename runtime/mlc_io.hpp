#ifndef AURORA_IO_HPP
#define AURORA_IO_HPP

#include <iostream>
#include <cstdlib>
#include <vector>
#include "mlc_string.hpp"

namespace mlc {
namespace io {

// Basic console output
int print(const String& s);
int println(const String& s);

// Error output
int eprint(const String& s);
int eprintln(const String& s);

// I/O functions
String read_line();
String read_all();

// Command line arguments
const std::vector<String>& args();
void set_args(std::vector<String>&& new_args);

} // namespace io
} // namespace mlc

#endif // AURORA_IO_HPP
