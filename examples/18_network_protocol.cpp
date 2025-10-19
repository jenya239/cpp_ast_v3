#include "../runtime/aurora_buffer.hpp"
#include <iostream>
#include <iomanip>
#include <vector>

using namespace aurora;

// Simple binary network protocol
// Format:
//   [Magic: u32] [Version: u16] [Type: u16] [Payload Length: u32] [Payload: bytes]

enum class MessageType : uint16_t {
    Ping = 0x01,
    Pong = 0x02,
    Data = 0x10,
    Command = 0x20
};

const uint32_t PROTOCOL_MAGIC = 0x41554F52;  // "AUOR" (Aurora)

struct Message {
    uint16_t version;
    MessageType type;
    Bytes payload;
};

// Serialize message to buffer
Buffer serialize_message(const Message& msg) {
    Buffer buf;
    BinaryWriter writer(buf, Endian::Big);  // Network byte order
    
    writer.write_u32(PROTOCOL_MAGIC);
    writer.write_u16(msg.version);
    writer.write_u16(static_cast<uint16_t>(msg.type));
    writer.write_u32(static_cast<uint32_t>(msg.payload.size()));
    writer.write_bytes(msg.payload);
    
    return buf;
}

// Deserialize message from buffer
Message deserialize_message(Buffer& buf) {
    BinaryReader reader(buf, Endian::Big);
    
    // Validate magic
    uint32_t magic = reader.read_u32();
    if (magic != PROTOCOL_MAGIC) {
        throw std::runtime_error("Invalid protocol magic");
    }
    
    Message msg;
    msg.version = reader.read_u16();
    msg.type = static_cast<MessageType>(reader.read_u16());
    
    uint32_t payload_len = reader.read_u32();
    msg.payload = reader.read_bytes(payload_len);
    
    return msg;
}

void print_buffer_hex(const Buffer& buf) {
    std::cout << "  [";
    for (size_t i = 0; i < buf.size() && i < 40; i++) {
        if (i > 0) std::cout << " ";
        std::cout << std::hex << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(buf[i]);
    }
    if (buf.size() > 40) std::cout << " ...";
    std::cout << "]" << std::dec << std::endl;
}

int main() {
    std::cout << "=== Network Protocol Demo ===" << std::endl << std::endl;
    
    // 1. Ping message (no payload)
    std::cout << "1. Ping Message" << std::endl;
    Message ping;
    ping.version = 1;
    ping.type = MessageType::Ping;
    ping.payload = Bytes();
    
    auto ping_buf = serialize_message(ping);
    std::cout << "  Serialized (" << ping_buf.size() << " bytes):" << std::endl;
    print_buffer_hex(ping_buf);
    
    auto ping_parsed = deserialize_message(ping_buf);
    std::cout << "  Parsed: version=" << ping_parsed.version 
              << ", type=" << static_cast<int>(ping_parsed.type)
              << ", payload=" << ping_parsed.payload.size() << " bytes" << std::endl;
    std::cout << std::endl;
    
    // 2. Data message with text payload
    std::cout << "2. Data Message with Text" << std::endl;
    String text("Hello from Aurora!");
    
    Message data;
    data.version = 1;
    data.type = MessageType::Data;
    data.payload = text.to_bytes();
    
    auto data_buf = serialize_message(data);
    std::cout << "  Serialized (" << data_buf.size() << " bytes):" << std::endl;
    print_buffer_hex(data_buf);
    
    auto data_parsed = deserialize_message(data_buf);
    String received_text = String::from_bytes(data_parsed.payload);
    std::cout << "  Parsed: version=" << data_parsed.version 
              << ", type=" << static_cast<int>(data_parsed.type) << std::endl;
    std::cout << "  Text: \"" << received_text.as_std_string() << "\"" << std::endl;
    std::cout << std::endl;
    
    // 3. Command message with structured payload
    std::cout << "3. Command Message with Structured Payload" << std::endl;
    
    // Build structured payload
    Buffer payload_buf;
    BinaryWriter payload_writer(payload_buf, Endian::Big);
    
    payload_writer.write_u8(0x05);  // Command ID
    payload_writer.write_length_prefixed_string(String("start"));
    payload_writer.write_u32(12345);  // Parameter
    
    Message cmd;
    cmd.version = 1;
    cmd.type = MessageType::Command;
    cmd.payload = payload_buf.to_bytes();
    
    auto cmd_buf = serialize_message(cmd);
    std::cout << "  Serialized (" << cmd_buf.size() << " bytes):" << std::endl;
    print_buffer_hex(cmd_buf);
    
    auto cmd_parsed = deserialize_message(cmd_buf);
    std::cout << "  Parsed: version=" << cmd_parsed.version 
              << ", type=" << static_cast<int>(cmd_parsed.type) << std::endl;
    
    // Parse structured payload
    Buffer payload_parse(cmd_parsed.payload);
    BinaryReader payload_reader(payload_parse, Endian::Big);
    
    uint8_t cmd_id = payload_reader.read_u8();
    String cmd_name = payload_reader.read_length_prefixed_string();
    uint32_t param = payload_reader.read_u32();
    
    std::cout << "  Command: id=" << static_cast<int>(cmd_id)
              << ", name=\"" << cmd_name.as_std_string() << "\""
              << ", param=" << param << std::endl;
    std::cout << std::endl;
    
    // 4. Multiple messages in a stream
    std::cout << "4. Message Stream (Multiple Messages)" << std::endl;
    
    std::vector<Buffer> messages;
    messages.push_back(serialize_message(ping));
    messages.push_back(serialize_message(data));
    messages.push_back(serialize_message(cmd));
    
    // Combine into one buffer (simulating network stream)
    Buffer stream;
    for (const auto& msg_buf : messages) {
        stream.append(msg_buf.to_bytes());
    }
    
    std::cout << "  Stream size: " << stream.size() << " bytes" << std::endl;
    std::cout << "  Messages in stream: " << messages.size() << std::endl;
    
    // Parse messages from stream
    BinaryReader stream_reader(stream, Endian::Big);
    int msg_count = 0;
    
    while (stream_reader.has_remaining(12)) {  // Minimum message size
        size_t start_pos = stream_reader.position();
        
        // Read header
        uint32_t magic = stream_reader.read_u32();
        if (magic != PROTOCOL_MAGIC) break;
        
        uint16_t version = stream_reader.read_u16();
        MessageType type = static_cast<MessageType>(stream_reader.read_u16());
        uint32_t payload_len = stream_reader.read_u32();
        
        // Skip payload
        stream_reader.skip(payload_len);
        
        msg_count++;
        std::cout << "  Message #" << msg_count << ": type=" << static_cast<int>(type)
                  << ", size=" << (stream_reader.position() - start_pos) << " bytes" 
                  << std::endl;
    }
    
    std::cout << std::endl << "✓ Successfully processed " << msg_count << " messages!" << std::endl;

    return 0;
}
