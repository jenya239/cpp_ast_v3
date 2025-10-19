#include "../runtime/aurora_buffer.hpp"
#include <iostream>
#include <iomanip>

using namespace aurora;

void print_hex(const Buffer& buf) {
    std::cout << "Buffer (" << buf.size() << " bytes): ";
    for (size_t i = 0; i < buf.size(); i++) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(buf[i]) << " ";
    }
    std::cout << std::dec << std::endl;
}

int main() {
    std::cout << "=== Aurora Binary Buffer Demo ===" << std::endl << std::endl;

    // 1. Basic buffer operations
    std::cout << "1. Basic Buffer Operations" << std::endl;
    Buffer buf(100);  // Reserve 100 bytes
    std::cout << "Created buffer with capacity: " << buf.capacity() << std::endl;
    std::cout << "Current size: " << buf.size() << std::endl;
    std::cout << std::endl;

    // 2. Writing integers with different endianness
    std::cout << "2. Writing Integers (Little Endian)" << std::endl;
    BinaryWriter writer_le(buf, Endian::Little);
    writer_le.write_u8(0x12);
    writer_le.write_u16(0x3456);
    writer_le.write_u32(0x789ABCDE);
    print_hex(buf);
    std::cout << std::endl;

    // 3. Writing same data with big endian
    std::cout << "3. Writing Integers (Big Endian)" << std::endl;
    Buffer buf_be;
    BinaryWriter writer_be(buf_be, Endian::Big);
    writer_be.write_u8(0x12);
    writer_be.write_u16(0x3456);
    writer_be.write_u32(0x789ABCDE);
    print_hex(buf_be);
    std::cout << std::endl;

    // 4. Reading back the data
    std::cout << "4. Reading Back (Little Endian)" << std::endl;
    BinaryReader reader_le(buf, Endian::Little);
    auto val1 = reader_le.read_u8();
    auto val2 = reader_le.read_u16();
    auto val3 = reader_le.read_u32();
    std::cout << "u8:  0x" << std::hex << static_cast<int>(val1) << std::endl;
    std::cout << "u16: 0x" << std::hex << val2 << std::endl;
    std::cout << "u32: 0x" << std::hex << val3 << std::dec << std::endl;
    std::cout << std::endl;

    // 5. Writing floats
    std::cout << "5. Writing Floats" << std::endl;
    Buffer float_buf;
    BinaryWriter float_writer(float_buf);
    float_writer.write_f32(3.14159f);
    float_writer.write_f64(2.718281828);
    print_hex(float_buf);
    
    BinaryReader float_reader(float_buf);
    std::cout << "f32: " << float_reader.read_f32() << std::endl;
    std::cout << "f64: " << float_reader.read_f64() << std::endl;
    std::cout << std::endl;

    // 6. Writing strings
    std::cout << "6. Writing Strings" << std::endl;
    Buffer str_buf;
    BinaryWriter str_writer(str_buf);
    
    String hello("Hello");
    str_writer.write_string(hello);
    str_writer.write_u8(' ');
    str_writer.write_cstring(String("World"));
    
    print_hex(str_buf);
    
    BinaryReader str_reader(str_buf);
    auto s1 = str_reader.read_string(5);
    auto space = str_reader.read_u8();
    auto s2 = str_reader.read_cstring();
    std::cout << "Strings: \"" << s1.as_std_string() << "\" + \""
              << s2.as_std_string() << "\"" << std::endl;
    std::cout << std::endl;

    // 7. Length-prefixed data
    std::cout << "7. Length-Prefixed Strings" << std::endl;
    Buffer lp_buf;
    BinaryWriter lp_writer(lp_buf);
    
    lp_writer.write_length_prefixed_string(String("First"));
    lp_writer.write_length_prefixed_string(String("Second message"));
    
    print_hex(lp_buf);
    
    BinaryReader lp_reader(lp_buf);
    auto msg1 = lp_reader.read_length_prefixed_string();
    auto msg2 = lp_reader.read_length_prefixed_string();
    std::cout << "Message 1: " << msg1.as_std_string() << std::endl;
    std::cout << "Message 2: " << msg2.as_std_string() << std::endl;
    std::cout << std::endl;

    // 8. Varint encoding
    std::cout << "8. Varint Encoding (Compact Integers)" << std::endl;
    Buffer varint_buf;
    BinaryWriter varint_writer(varint_buf);
    
    std::cout << "Writing: 1, 150, 1000000" << std::endl;
    varint_writer.write_varint(1);
    varint_writer.write_varint(150);
    varint_writer.write_varint(1000000);
    
    print_hex(varint_buf);
    std::cout << "Size: " << varint_buf.size() << " bytes (vs 24 bytes for 3x uint64)" << std::endl;
    
    BinaryReader varint_reader(varint_buf);
    std::cout << "Reading back: ";
    std::cout << varint_reader.read_varint() << ", ";
    std::cout << varint_reader.read_varint() << ", ";
    std::cout << varint_reader.read_varint() << std::endl;
    std::cout << std::endl;

    // 9. Buffer position tracking
    std::cout << "9. Buffer Position Tracking" << std::endl;
    Buffer pos_buf;
    BinaryWriter pos_writer(pos_buf);
    pos_writer.write_u32(0xDEADBEEF);
    pos_writer.write_u32(0xCAFEBABE);
    pos_writer.write_u32(0x12345678);
    
    BinaryReader pos_reader(pos_buf);
    std::cout << "Position: " << pos_reader.position() << std::endl;
    pos_reader.read_u32();
    std::cout << "After read_u32(): " << pos_reader.position() << std::endl;
    std::cout << "Remaining: " << pos_reader.remaining() << " bytes" << std::endl;
    
    pos_reader.set_position(0);  // Reset
    std::cout << "After reset: position=" << pos_reader.position() << std::endl;
    std::cout << std::endl;

    // 10. Endianness detection
    std::cout << "10. System Endianness" << std::endl;
    std::cout << "Native endianness: " 
              << (endian::native() == Endian::Little ? "Little" : "Big") << " Endian"
              << std::endl;

    return 0;
}
