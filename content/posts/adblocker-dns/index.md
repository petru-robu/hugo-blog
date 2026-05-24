+++
date = '2026-05-24T21:23:58+03:00'
draft = false
title = 'Tutorial: Adblocker - DNS Resolver in C++'

categories = ["Programming"]
tags = ["Tutorial", "C++", "DNS"]
+++

# Description

The goal is to write a DNS adblocker in C++, that works like [pi-hole](https://pi-hole.net/).

The flow goes like this:
- Computer acceses a domain for a certain website
- The DNS Resolver is called to resolve the ip adress of the website
- Here is where the blocking comes in, if the server requested is blacklisted, we immediately block it, by returning `0.0.0.0`.

## Steps
- **DNS packet parsing**: this is implemented by hand in C++, we need to extract data from the packets (parsing), but also to construct packets (serializing). This requires some bit manipulation, as we will see.

- **UDP server**: The UDP server will send and receive DNS packets.

- **Recursive resolution**: After we get a package, what do we do with it? We need to do recursive resolution, to ask nameservers one by one if they know how to resolve the domain. If not, continue in depth to aditional nameservers provided by the DNS packet.

- **Caching**: A caching mecahnism is essential for efficiency. If we know how a domain was resolved, resolve it from cache next time. Recursive resolution may be expensive.

- **DNS over HTTPS**: DNS packets are unencrypted by default, the DNS specification does not provide a security measure. A middle man may come and alter the DNS package. But, fortunately, we have HTTPS, so we can send DNS packages over HTTPS.

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

To be continued.