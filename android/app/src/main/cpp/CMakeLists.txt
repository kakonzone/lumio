cmake_minimum_required(VERSION 3.22.1)
project(lumio_security)

add_library(lumio_security SHARED
    secrets.cpp
)

target_compile_options(lumio_security PRIVATE
    -O3
    -fvisibility=hidden
    -ffunction-sections
    -fdata-sections
)

target_link_options(lumio_security PRIVATE
    -Wl,--gc-sections
)

find_library(log-lib log)
target_link_libraries(lumio_security ${log-lib})
