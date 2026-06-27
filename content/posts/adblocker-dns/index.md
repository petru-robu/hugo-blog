+++
date = '2026-05-24T21:23:58+03:00'
draft = false
title = 'Tutorial: Adblocker - DNS Resolver in C++'

categories = ["Programming"]
tags = ["Tutorial", "C++", "DNS"]
+++

# Description

The goal is to write a DNS adblocker in C++, that works like [pi-hole](https://pi-hole.net/)

The flow goes like this:
- Computer acceses a domain for a certain website
- The DNS Resolver is called to resolve the ip adress of the website
- Here is where the blocking comes in, if the server requested is blacklisted, we immediately block it, by returning `0.0.0.0`.

## Steps
- **DNS packet parsing**: this is implemented by hand in C++, we need to extract data from the packets (parsing), but also to construct packets (serializing). This requires some bit manipulation, as we will see.

- **UDP server**: The UDP server will send and receive DNS packets.

- **Recursive resolution**: After we get a package, what do we do with it? We need to do recursive resolution, to ask nameservers one by one if they know how to resolve the domain. If not, continue in depth to aditional nameservers provided by the DNS packet.

---

Let's get started:

# Part 1 - Project Setup

## Installing CMake
As I said we are doing this in C++, so we need to setup our project somehow. The build system we are using is [CMake](https://cmake.org/). You need to install CMake on your system first. You may do it like this:


```bash
sudo dnf install cmake 
```

As I am using Fedora, I will provide Fedora commands. You need to adapt to your own package mmanager.

## Installing Boost
We are also linking [Boost.Asio](https://www.boost.org/libs/asio/)(used for the UDP server), so you will need boost on your system:

```bash
sudo dnf install boost-devel
```

## Configuring project
We will organize the project in the following way:
- `app/main.cpp` - this is our entrypoint
- `inc/` - include folder that will contain our `.hpp` headers
- `src/` - source folder that will contain `.cpp` header implementation
- `res/` - folder that will contain resources, ex: `root_servers.txt` (the root DNS servers we will use for recursive resolution)
- CMakeLists.txt - Cmake build config file

CMakeLists.txt will look like this:

```
cmake_minimum_required(VERSION 3.20)

project(adblocker
    VERSION 0.1.0
    DESCRIPTION "AdBlocking project"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Threads REQUIRED)

add_library(dns_resolver_core
    src/dns_name.cpp
    src/dns_message.cpp
    src/udp_server.cpp
    src/rec_resolver.cpp
)

target_include_directories(dns_resolver_core
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/inc
)

target_link_libraries(dns_resolver_core
    PUBLIC
        Threads::Threads
)

target_compile_features(dns_resolver_core
    PUBLIC
        cxx_std_20
)

add_executable(dns-resolver
    app/main.cpp
)

target_link_libraries(dns-resolver
    PRIVATE
        dns_resolver_core
)
```

# Part 2 - DNS parsing

## DNS names and pointer compression

The DNS packets have a certain structure. You can read about it here: (https://datatracker.ietf.org/doc/html/rfc1035)[https://datatracker.ietf.org/doc/html/rfc1035].

First, we need to parse a DNS domain name, for this we have dns_name:
```cpp
namespace dns {
    class DnsNameParser {
    public:
        std::string parse(const Buffer& packet, std::size_t& offset);
        static void write_uncompressed(Buffer& ouput, const std::string& name);
    };
}
```

DNS names inside a message may use compression pointers to avoid repeating suffixes. In a DNS message we may have something like this:
```
Question:    www.example.com
Answer:      www.example.com
Authority:   example.com
Nameserver:  ns1.example.com
Additional:  ns1.example.com
```
To avoid repeating example.com every time we use compression pointers. This is how it works:

First we know where the name is at a certain offset, suppose it is like this:
```
Offset  Bytes
12      07 "example" 03 "com" 00
```

After that, instead of writing `www.example.com` fully, we can do:
```
03 "www" C0 0C
```

`C0 0C` is the pointer that contains the offset. DNS marks the first two bits to know it is a pointer:
```
11 | 000000 | 00001100
```
The remaining 14 bits contain the offset (12).

In `DnsNameParser::parse` we parse compressed packages.


## DNS messages

We model the DNS packet like this: 
```cpp
    struct DnsFlags {
        bool qr{};              
        std::uint8_t opcode{};  
        bool aa{};             
        bool tc{};              
        bool rd{};              
        bool ra{};             
        std::uint8_t z{};       
        std::uint8_t rcode{};
        
        static DnsFlags from_u16(std::uint16_t value);
        std::uint16_t to_u16() const;
    };

    /*
        Info about the dns packet content.
    */
    struct DnsHeader {
        std::uint16_t id{};
        DnsFlags flags{};
        std::uint16_t question_count{};
        std::uint16_t answer_count{};
        std::uint16_t authority_count{};
        std::uint16_t additional_count{};
    };

    /*
        Question:
        <name> <class> <type>
        www.example.com AAAA
    */
    struct DnsQuestion {
        std::string qname;
        RecordType qtype{ RecordType::A };
        RecordClass qclass{ RecordClass::IN };
    };

    /*
        Record:
        <name> <ttl> <class> <type> <data>
        www.example.com 3600 IN AAAA data
    */
    struct DnsRecord {
        std::string name;
        RecordType type{ RecordType::A };
        RecordClass klass{ RecordClass::IN };
        std::uint32_t ttl{};
        Buffer rdata;
    };

    /*
        Final DnsPacket structure:
    */
    struct DnsMessage {
        DnsHeader header;
        std::vector<DnsQuestion> questions;
        std::vector<DnsRecord> answers;
        std::vector<DnsRecord> authorities;
        std::vector<DnsRecord> additionals;

        static DnsMessage parse(const Buffer& packet);
        Buffer serialize() const;
    };
```

Because we need to construct and also parse DNS packets, we need DNS serializer and parser classes:

```cpp
    class DnsMessageParser {
    public:
        static std::uint16_t read_u16(const Buffer& packet, std::size_t& offset);
        static std::uint32_t read_u32(const Buffer& packet, std::size_t& offset);

        static DnsHeader parse_header(const Buffer& packet, std::size_t& offset);
        static DnsQuestion parse_question(const Buffer& packet, std::size_t& offset);
        static DnsRecord parse_record(const Buffer& packet, std::size_t& offset);

        static void parse_questions(
            const Buffer& packet,
            std::size_t& offset,
            std::uint16_t count,
            std::vector<DnsQuestion>& output
        );

        static void parse_records(
            const Buffer& packet,
            std::size_t& offset,
            std::uint16_t count,
            std::vector<DnsRecord>& output
        );
    };
    
    class DnsMessageSerializer {
    public:
        static void write_u16(Buffer& output, std::uint16_t value);
        static void write_u32(Buffer& output, std::uint32_t value);

        static void write_header(Buffer& output, const DnsHeader& header);
        static void write_question(Buffer& output, const DnsQuestion& question);
        static void write_record(Buffer& output, const DnsRecord& record);

        static void write_questions(Buffer& output, const std::vector<DnsQuestion>& questions);

        static void write_records(Buffer& output, const std::vector<DnsRecord>& records);
    };
```

All of the classes above are implemented in the respective `.cpp` files. I won't paste all the code here because it is too much. You can find it in the repository.


# Part 3 - Recursive Resolution
This represents a DNS server that the resolver can contact:

```cpp
    class NameServer {
        private:
            std::string name;
            std::string ip;

        public:
            NameServer(std::string name, std::string ip);
            const std::string& get_name() const;
            const std::string& get_ip() const;
    };
```


This is the resolver:

```cpp
class RecursiveResolver {
    private:
        DnsMessage query;
        std::vector<NameServer> root_servers;

        void read_root_servers(const std::string& file_path);

        // send query over UDP
        DnsMessage query_server(const std::string& server_ip, const DnsMessage& query); 

        // send query over TCP mainly as a fallback
        DnsMessage query_server_tcp(const std::string& server_ip, const DnsMessage& query);

        // recursive resolution
        DnsMessage resolve_impl(
            DnsMessage query,
            std::size_t depth,
            std::unordered_set<std::string>& active_queries
        );

        // extract glue nameservers
        std::vector<NameServer> extract_glue_nameservers(
            const DnsMessage& response
        ) const;

        // resolve nameserver ips
        std::vector<NameServer> resolve_nameserver_ips(
            const DnsMessage& response,
            std::size_t depth,
            std::unordered_set<std::string>& active_queries
        );

    public:
        RecursiveResolver(DnsMessage query);
        DnsMessage resolve(DnsMessage query);
};
```

The flow goes like this:
```
Start with roots
      │
      ▼
Query current servers
      │
      ├── Answer ───────────────► Return
      ├── NXDOMAIN/NODATA ──────► Return
      ├── Referral with glue ───► Use glue IPs
      ├── Referral without glue ► Resolve NS IPs
      └── Failure ──────────────► Try another server
```

Implementation is in the repo.


# Part 4 - Adblocking functionality

To add adblocking functionality, we just mantain a blocklist and return NXDOMAIN before upstream resolution.
```cpp
class DomainBlocklist {
public:
    explicit DomainBlocklist(const std::string& file_path);

    bool is_blocked(const std::string& domain) const;
    std::size_t size() const;

private:
    std::unordered_set<std::string> blocked_domains;
};
```

# Results

Finally, the resolution code is this:

```cpp
Buffer handle_query_rr(
        const Buffer& request,
        const DomainBlocklist& blocklist
    ) {
        DnsMessage query = DnsMessage::parse(request);
        DnsMessage response;

        if (query.questions.size() != 1) {
            response.header.flags.rcode =
                static_cast<std::uint8_t>(ResponseCode::FormErr);
        } else if (blocklist.is_blocked(query.questions.front().qname)) {
            response.header.flags.rcode =
                static_cast<std::uint8_t>(ResponseCode::NXDomain);
        } else if (!query.header.flags.rd) {
            // There is no cache to answer non-recursive requests from.
            response.header.flags.rcode =
                static_cast<std::uint8_t>(ResponseCode::Refused);
        } else {
            try {
                RecursiveResolver resolver(query, blocklist);
                response = resolver.resolve(query);
            } catch (const std::exception& error) {
                std::cerr << "Resolution error: " << error.what() << '\n';
                response.header.flags.rcode =
                    static_cast<std::uint8_t>(ResponseCode::ServFail);
            }
        }

        response.header.id = query.header.id;
        response.header.flags.qr = true;
        response.header.flags.opcode = query.header.flags.opcode;
        response.header.flags.aa = false;
        response.header.flags.rd = query.header.flags.rd;
        response.header.flags.ra = true;
        response.questions = query.questions;

        return response.serialize();
    }
```

Start the app and do a dig:

```bash
dig @127.0.0.1 -p 5300 subdomain.doubleclick.net A
```

It returns `NXDOMAIN`.