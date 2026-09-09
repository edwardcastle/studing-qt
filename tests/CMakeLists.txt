# ---------------------------------------------------------------------------
# tests/CMakeLists.txt
#
# TEACHING NOTE
# Each test is its own small executable built with qt_add_executable. They
# compile the production sources directly instead of linking a library, which
# keeps the example simple: in a bigger project you would move src/core and
# src/models into a static library and link that here instead.
#
# Run them with:   ctest --test-dir build --output-on-failure
# ---------------------------------------------------------------------------

find_package(Qt6 6.4 REQUIRED COMPONENTS Test)

# Sources shared by the tests. Note that no GUI class appears in this list.
set(DEVBOARD_CORE_SOURCES
    ${CMAKE_SOURCE_DIR}/src/core/Task.h
    ${CMAKE_SOURCE_DIR}/src/core/Task.cpp
    ${CMAKE_SOURCE_DIR}/src/core/TaskStore.h
    ${CMAKE_SOURCE_DIR}/src/core/TaskStore.cpp
)

set(DEVBOARD_MODEL_SOURCES
    ${CMAKE_SOURCE_DIR}/src/models/TaskListModel.h
    ${CMAKE_SOURCE_DIR}/src/models/TaskListModel.cpp
    ${CMAKE_SOURCE_DIR}/src/models/TaskFilterModel.h
    ${CMAKE_SOURCE_DIR}/src/models/TaskFilterModel.cpp
)

set(DEVBOARD_SCANNER_SOURCES
    ${CMAKE_SOURCE_DIR}/src/scanner/ScanTypes.h
    ${CMAKE_SOURCE_DIR}/src/scanner/ScanWorker.h
    ${CMAKE_SOURCE_DIR}/src/scanner/ScanWorker.cpp
)

# A helper so each test is three lines instead of ten.
function(devboard_add_test name)
    qt_add_executable(${name} ${ARGN})
    target_include_directories(${name} PRIVATE ${CMAKE_SOURCE_DIR}/src)
    target_link_libraries(${name} PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    add_test(NAME ${name} COMMAND ${name})

    # Qt Test writes to stdout; tell CTest to treat a non-zero exit as failure
    # (the default) and give the test a generous but finite time budget.
    set_tests_properties(${name} PROPERTIES TIMEOUT 120)
endfunction()

devboard_add_test(tst_taskstore
    tst_taskstore.cpp
    ${DEVBOARD_CORE_SOURCES}
)

devboard_add_test(tst_tasklistmodel
    tst_tasklistmodel.cpp
    ${DEVBOARD_CORE_SOURCES}
    ${DEVBOARD_MODEL_SOURCES}
)

devboard_add_test(tst_scanworker
    tst_scanworker.cpp
    ${DEVBOARD_SCANNER_SOURCES}
)
