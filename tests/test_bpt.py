import json
from ci.fxt import CMakeProjectFactory


def test_simple(tmp_project_factory: CMakeProjectFactory) -> None:
    proj = tmp_project_factory('meow')
    proj.write(
        'CMakeLists.txt', r'''
        cmake_minimum_required(VERSION 3.11)
        project(MyTestProject)

        include(${PMM_INCLUDE})
        pmm(BPT DEPENDENCIES fmt@8.1.1)
        pmm(BPT DEPENDENCIES spdlog@1.10.0)

        add_executable(app app.cpp)
        target_link_libraries(app PRIVATE spdlog::spdlog)
        ''')
    proj.write(
        'app.cpp', r'''
        #include <spdlog/spdlog.h>

        int main() {
            spdlog::info("I am a very simple log message!");
        }
    ''')
    proj.configure()
    proj.build()


def test_dep_files(tmp_project_factory: CMakeProjectFactory) -> None:
    proj = tmp_project_factory('meow')
    proj.write(
        'CMakeLists.txt', r'''
        cmake_minimum_required(VERSION 3.11)
        project(MyTestProject)

        include(${PMM_INCLUDE})
        pmm(BPT DEP_FILES depends.yaml)

        add_executable(app app.cpp)
        target_link_libraries(app PRIVATE spdlog::spdlog)
    ''')
    proj.write('depends.yaml', json.dumps({'dependencies': ['spdlog@1.10.0', 'fmt@8.1.1']}))
    proj.write(
        'app.cpp', r'''
        #include <spdlog/spdlog.h>

        int main() {
            spdlog::info("I am another simple log message");
        }
        ''')
    proj.configure()
    proj.build()
