#include "mlc_io.hpp"

#include <iostream>
#include <sstream>

namespace mlc::io {
namespace {
std::vector<String> g_args;

int write_to_stream(std::ostream& stream, const String& value, bool newline) {
    stream << value.as_std_string();
    if (newline) {
        stream << '\n';
    }
    stream.flush();
    return 0;
}
} // namespace

int print(const String& value) {
    return write_to_stream(std::cout, value, false);
}

int println(const String& value) {
    return write_to_stream(std::cout, value, true);
}

int eprint(const String& value) {
    return write_to_stream(std::cerr, value, false);
}

int eprintln(const String& value) {
    return write_to_stream(std::cerr, value, true);
}

String read_line() {
    std::string line;
    if (!std::getline(std::cin, line)) {
        return String("");
    }
    return String(line);
}

String read_all() {
    std::ostringstream oss;
    oss << std::cin.rdbuf();
    return String(oss.str());
}

const std::vector<String>& args() {
    return g_args;
}

void set_args(std::vector<String>&& new_args) {
    g_args = std::move(new_args);
}

} // namespace mlc::io
