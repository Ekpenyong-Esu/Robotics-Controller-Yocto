# ==============================================================================
# Vision Processor Library
# ==============================================================================

add_library(vision_processor STATIC
    vision_processor.cpp
)

target_include_directories(vision_processor PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)


# Link OpenCV if available
if(OPENCV_FOUND)
    target_link_libraries(vision_processor opencv)
    target_compile_definitions(vision_processor PRIVATE HAVE_OPENCV=1)
else()
    message(WARNING "OpenCV not found or not enabled: vision_processor will be built without OpenCV support.")
endif()

message(STATUS "Vision processor configured")
