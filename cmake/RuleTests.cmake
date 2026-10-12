# CTest fixtures compile each suite once, including when running a filtered test.
# Prefer the activated toolchain over a newer system Python without rlc.
# Respect an explicitly supplied strategy/interpreter.
if(NOT DEFINED Python3_FIND_STRATEGY)
  set(Python3_FIND_STRATEGY LOCATION)
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
execute_process(COMMAND "${Python3_EXECUTABLE}" -c "from rlc.program import Program"
  RESULT_VARIABLE rule_python_status ERROR_VARIABLE rule_python_error)
if(NOT rule_python_status EQUAL 0)
  message(FATAL_ERROR
    "Rule tests require rlc in ${Python3_EXECUTABLE}. Activate the repository Python environment or set Python3_EXECUTABLE. ${rule_python_error}")
endif()
find_program(RLC_TEST_COMPILER NAMES rlc)
if(NOT RLC_TEST_COMPILER)
  message(FATAL_ERROR "Rule tests require rlc; activate the repository Python environment")
endif()
set(rule_test_runner "${PROJECT_SOURCE_DIR}/tools/ctest_rules.py")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
  "${PROJECT_SOURCE_DIR}/tests/baseline.rl"
  "${PROJECT_SOURCE_DIR}/tests/known_discrepancies.rl"
  "${PROJECT_SOURCE_DIR}/tests/known_discrepancies.json"
  "${rule_test_runner}")
execute_process(COMMAND "${Python3_EXECUTABLE}" "${rule_test_runner}" list
  RESULT_VARIABLE discovery_status OUTPUT_VARIABLE discovered_tests
  ERROR_VARIABLE discovery_error OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT discovery_status EQUAL 0)
  message(FATAL_ERROR "Rule test discovery failed: ${discovery_error}")
endif()
foreach(suite baseline discrepancies)
  add_test(NAME rules.compile.${suite}
    COMMAND "${Python3_EXECUTABLE}" "${rule_test_runner}" build
      --suite ${suite} --directory "${PROJECT_BINARY_DIR}/rule-tests/${suite}"
      --compiler "${RLC_TEST_COMPILER}")
  set_tests_properties(rules.compile.${suite} PROPERTIES
    FIXTURES_SETUP rules_${suite} LABELS "rules;setup" TIMEOUT 600)
endforeach()
string(REPLACE "\n" ";" discovered_tests "${discovered_tests}")
foreach(entry IN LISTS discovered_tests)
  string(REPLACE "|" ";" fields "${entry}")
  list(GET fields 0 suite)
  list(GET fields 1 test_name)
  set(ctest_name "rules.${suite}.${test_name}")
  add_test(NAME "${ctest_name}"
    COMMAND "${Python3_EXECUTABLE}" "${rule_test_runner}" run
      --suite ${suite} --directory "${PROJECT_BINARY_DIR}/rule-tests/${suite}"
      --test "${test_name}")
  set_tests_properties("${ctest_name}" PROPERTIES
    FIXTURES_REQUIRED rules_${suite} LABELS "rules;${suite}" TIMEOUT 30)
  if(suite STREQUAL "discrepancies")
    set_tests_properties("${ctest_name}" PROPERTIES
      SKIP_RETURN_CODE 77 LABELS "rules;discrepancies;expected-failure")
  endif()
endforeach()
