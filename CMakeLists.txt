cmake_minimum_required (VERSION 3.10)
project(GodotExtensions)
find_package(rlc REQUIRED PATHS "../.venv/share/rlc/cmake/rlcConfig.cmake")
include(ExternalProject)

if (NOT DEFINED GODOT_EDITOR)
	message(FATAL_ERROR "godot editor location not found, specify it with -DGODOT_EDITOR=PATH")
endif()

ExternalProject_Add(
  godot-cpp
  PREFIX ${CMAKE_CURRENT_BINARY_DIR}
  GIT_REPOSITORY https://github.com/godotengine/godot-cpp
  GIT_TAG 4.3
  CONFIGURE_COMMAND ""
  BUILD_COMMAND ""
  INSTALL_COMMAND ""
  UPDATE_DISCONNECTED TRUE
)

set(GODOT_API_JSON ${CMAKE_CURRENT_BINARY_DIR}/extension_api.json)
add_custom_command(OUTPUT ${GODOT_API_JSON}
				   COMMAND cd ${CMAKE_CURRENT_BINARY_DIR}
				   COMMAND ${GODOT_EDITOR} --dump-extension-api
				   DEPENDS ${GODOT_EDITOR})
add_custom_target(godot_api_json ALL DEPENDS ${GODOT_API_JSON})


set(GODOT_CPP ${CMAKE_CURRENT_BINARY_DIR}/src/godot-cpp)

function(build_rules_for_target ARCH OS LIBGODOT_TARGET_TYPE)
  set(LIB_GODOT_FILENAME libgodot-cpp.${OS}.template_${LIBGODOT_TARGET_TYPE}.${ARCH}.a)
  set(LIB_GODOT_REMOTE ${GODOT_CPP}/bin/${LIB_GODOT_FILENAME})
  set(LIB_GODOT ${CMAKE_CURRENT_BINARY_DIR}/${LIB_GODOT_FILENAME})
  set(lib_godot_target lib_godot_${ARCH}_${OS}_${LIBGODOT_TARGET_TYPE})

  add_custom_command(OUTPUT ${LIB_GODOT}
				   COMMAND cd ${GODOT_CPP} && scons platform=linux verbose=true custom_api_file=${GODOT_API_JSON} target=template_${LIBGODOT_TARGET_TYPE}
				   COMMAND ${CMAKE_COMMAND} -E  copy_if_different ${LIB_GODOT_REMOTE}  ${LIB_GODOT}
				   DEPENDS ${GODOT_API_JSON} godot-cpp)

  add_custom_target(${lib_godot_target} ALL DEPENDS ${LIB_GODOT})

  set(RLC_RULES_LIB_NAME rlcrules_${ARCH}_${OS}_${LIBGODOT_TARGET_TYPE})
  set(RLC_RULES_LIB lib${RLC_RULES_LIB_NAME}.a)
  set(TARGET_NAME skirmish_rules_${ARCH}_${OS}_${LIBGODOT_TARGET_TYPE})
  rlc(${TARGET_NAME}
	COMPILE
	INPUT src/rules.rl
	OUTPUT ${RLC_RULES_LIB}
	GODOT rules.inc
	EXTRA_ARGS --emit-precondition-checks --emit-bound-checks --abort-symbol rlc_abort
	)

  set(LIB_NAME rules_${ARCH}_${OS}_${LIBGODOT_TARGET_TYPE})
  add_library(${LIB_NAME} SHARED ./src/gdexample.cpp ./src/rlc_runtime.c)
  target_include_directories(${LIB_NAME} PUBLIC ${GODOT_CPP}/include/ ${GODOT_CPP}/gen/include ${GODOT_CPP}/gdextension/ ${CMAKE_CURRENT_BINARY_DIR} ${RLC_INCLUDE_DIR})
  target_link_directories(${LIB_NAME} PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
  target_link_libraries(${LIB_NAME} PUBLIC ${RLC_RULES_LIB_NAME} ${LIB_GODOT_FILENAME})
  add_dependencies(${LIB_NAME} ${TARGET_NAME} ${lib_godot_target})
endfunction()

build_rules_for_target("x86_64" "linux" "release")
build_rules_for_target("x86_64" "linux" "debug")

set(WASM_LIB_GODOT_FILENAME libgodot-cpp.web.template_release.wasm32.nothreads.a)
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${WASM_LIB_GODOT_FILENAME}
				COMMAND cd ${GODOT_CPP} && scons platform=web verbose=true custom_api_file=${GODOT_API_JSON} target=template_release threads=0
				COMMAND ${CMAKE_COMMAND} -E  copy_if_different ${GODOT_CPP}/bin/${WASM_LIB_GODOT_FILENAME} ${CMAKE_CURRENT_BINARY_DIR}/${WASM_LIB_GODOT_FILENAME}
				DEPENDS ${GODOT_API_JSON} godot-cpp)
add_custom_target(libgodot_web_release ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${WASM_LIB_GODOT_FILENAME})

rlc(skirmish_rules_wasm32
	SHARED
	COMPILE
	INPUT src/rules.rl
	OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/librlcrules_web_release.o
	EXTRA_ARGS --emit-precondition-checks --emit-bound-checks --target=wasm32-unknown-emscripten --abort-symbol rlc_abort
)

add_custom_command(
	OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/librules_web_release.wasm
    COMMAND emcc ./src/rlc_runtime.c -I ${GODOT_CPP}/include/ -I  ${GODOT_CPP}/gen/include -I ${GODOT_CPP}/gdextension/ -I ${CMAKE_CURRENT_BINARY_DIR} -I ${RLC_INCLUDE_DIR} -o ${CMAKE_CURRENT_BINARY_DIR}/runtime.wasm.o -s SIDE_MODULE=1 -s -fno-exceptions -sSUPPORT_LONGJMP='wasm' -O3 -DWEB_ENABLED -DUNIX_ENABLED -DNDEBUG -DGDEXTENSION -Igdextension -s USE_PTHREADS=1 -sWASM_BIGINT -fvisibility=hidden -c
	COMMAND em++ ${CMAKE_CURRENT_SOURCE_DIR}/src/gdexample.cpp -I ${GODOT_CPP}/include/ -I  ${GODOT_CPP}/gen/include -I ${GODOT_CPP}/gdextension/ -I ${CMAKE_CURRENT_BINARY_DIR} -I ${RLC_INCLUDE_DIR} -std=c++17 -o ${CMAKE_CURRENT_BINARY_DIR}/librules_web_release.wasm  ${CMAKE_CURRENT_BINARY_DIR}/${WASM_LIB_GODOT_FILENAME} ${CMAKE_CURRENT_BINARY_DIR}/runtime.wasm.o ${CMAKE_CURRENT_BINARY_DIR}/librlcrules_web_release.o -s SIDE_MODULE=1 -s -fno-exceptions -sSUPPORT_LONGJMP='wasm' -O3 -DWEB_ENABLED -DUNIX_ENABLED -DNDEBUG -DGDEXTENSION -Igdextension -s USE_PTHREADS=0 -sWASM_BIGINT -fvisibility=hidden
	DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/gdexample.cpp ${CMAKE_CURRENT_BINARY_DIR}/${WASM_LIB_GODOT_FILENAME} ${CMAKE_CURRENT_BINARY_DIR}/librlcrules_web_release.o
	)

add_custom_target(rules_web_release ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/librules_web_release.wasm)

add_custom_target(editor
	COMMAND cd ${CMAKE_CURRENT_SOURCE_DIR} && ${GODOT_EDITOR} -e DEPENDS rules_x86_64_linux_debug)

add_custom_target(run
	COMMAND cd ${CMAKE_CURRENT_SOURCE_DIR} && ${GODOT_EDITOR} DEPENDS rules_x86_64_linux_debug)

add_custom_target(export-web
	COMMAND cd ${CMAKE_CURRENT_SOURCE_DIR} && ${GODOT_EDITOR} --export-release Web ${CMAKE_CURRENT_BINARY_DIR}/exports/skirmish.html DEPENDS rules_web_release)

add_custom_target(test-web
	COMMAND cd ${CMAKE_CURRENT_BINARY_DIR}/exports && vivaldi 127.0.0.1:8000 && python ${CMAKE_CURRENT_SOURCE_DIR}/tools/open_server.py
	DEPENDS export-web)
