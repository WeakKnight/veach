cmake_minimum_required(VERSION 3.20)
project(fsr3_reference CXX)

# The AMD FidelityFX SDK 1.1.4 download (ffx-api headers and the prebuilt, signed amd_fidelityfx_dx12.dll).
set(FFX_SDK "C:/Users/Administrator/Downloads/FidelityFX-SDK-v1.1.4" CACHE PATH "FidelityFX SDK 1.1.4 root")

add_executable(fsr3_reference main.cpp)
target_compile_features(fsr3_reference PRIVATE cxx_std_17)
target_include_directories(fsr3_reference PRIVATE "${FFX_SDK}/ffx-api/include")
target_link_libraries(fsr3_reference PRIVATE d3d12 dxgi "${FFX_SDK}/PrebuiltSignedDLL/amd_fidelityfx_dx12.lib")
target_compile_definitions(fsr3_reference PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
add_custom_command(TARGET fsr3_reference POST_BUILD
	COMMAND ${CMAKE_COMMAND} -E copy_if_different "${FFX_SDK}/PrebuiltSignedDLL/amd_fidelityfx_dx12.dll" $<TARGET_FILE_DIR:fsr3_reference>)
