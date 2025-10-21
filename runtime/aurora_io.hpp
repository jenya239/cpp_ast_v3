#ifndef AURORA_IO_HPP
#define AURORA_IO_HPP

#include "aurora_string.hpp"
#include <vector>

namespace aurora::io {

int print(const aurora::String& value);
int println(const aurora::String& value);
int eprint(const aurora::String& value);
int eprintln(const aurora::String& value);

aurora::String read_line();
aurora::String read_all();

const std::vector<aurora::String>& args();
void set_args(std::vector<aurora::String>&& new_args);

} // namespace aurora::io

#endif // AURORA_IO_HPP
