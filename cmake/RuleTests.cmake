# Python assertions reuse the exact Rulebook library linked by Godot.
if(NOT DEFINED Python3_FIND_STRATEGY)
  set(Python3_FIND_STRATEGY LOCATION)
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
set(rule_test_runner "${PROJECT_SOURCE_DIR}/tools/ctest_rules.py")
set(RULE_TEST_WRAPPER "${PROJECT_BINARY_DIR}/skirmish.py" CACHE FILEPATH
    "Generated Python bindings matching the Godot rules build")
set(RULE_TEST_LIBRARY "${PROJECT_BINARY_DIR}/librules_x86_64_linux_debug.so" CACHE FILEPATH
    "Existing Rulebook library linked by Godot; rule tests never compile it")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${PROJECT_SOURCE_DIR}/tests/python/baseline.py"
  "${PROJECT_SOURCE_DIR}/tests/python/known_discrepancies.py"
  "${PROJECT_SOURCE_DIR}/tests/known_discrepancies.json"
  "${rule_test_runner}")
execute_process(COMMAND "${Python3_EXECUTABLE}" "${rule_test_runner}" list
  RESULT_VARIABLE discovery_status OUTPUT_VARIABLE discovered_tests
  ERROR_VARIABLE discovery_error OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT discovery_status EQUAL 0)
  message(FATAL_ERROR "Rule test discovery failed: ${discovery_error}")
endif()
add_test(NAME rules.bindings
  COMMAND "${Python3_EXECUTABLE}" "${rule_test_runner}" check
    --wrapper "${RULE_TEST_WRAPPER}" --library "${RULE_TEST_LIBRARY}")
set_tests_properties(rules.bindings PROPERTIES
  FIXTURES_SETUP rules_bindings LABELS "rules;setup" TIMEOUT 180)
string(REPLACE "\n" ";" discovered_tests "${discovered_tests}")
foreach(entry IN LISTS discovered_tests)
  string(REPLACE "|" ";" fields "${entry}")
  list(GET fields 0 suite)
  list(GET fields 1 test_name)
  set(ctest_name "rules.${suite}.${test_name}")
  add_test(NAME "${ctest_name}"
    COMMAND "${Python3_EXECUTABLE}" "${rule_test_runner}" run
      --suite ${suite} --wrapper "${RULE_TEST_WRAPPER}" --library "${RULE_TEST_LIBRARY}"
      --test "${test_name}")
  set_tests_properties("${ctest_name}" PROPERTIES
    FIXTURES_REQUIRED rules_bindings LABELS "rules;${suite}" TIMEOUT 180)
  if(suite STREQUAL "discrepancies")
    set_tests_properties("${ctest_name}" PROPERTIES
      SKIP_RETURN_CODE 77 LABELS "rules;discrepancies;expected-failure")
  endif()
endforeach()
