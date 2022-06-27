from ci.fxt import CMakeProject, CMakeProjectFactory


def test_simple(tmp_project_factory: CMakeProjectFactory) -> None:
    proj = tmp_project_factory('meow')
    with proj.write_CMakeLists() as w:
        w.cmake_minimum_required('VERSION', '3.11')
        w.project('MyTestProject')
        w.include(r"${PMM_INCLUDE}")
        w.pmm("BPT", "DEPENDENCIES", "fmt@8.1.1")
        w.pmm("BPT", "DEPENDENCIES", "spdlog@1.10.0")
        w.add_executable('test-app', 'app.cpp')
        w.target_link_libraries('test-app', 'PRIVATE', 'spdlog::spdlog')
    proj.write(
        'app.cpp', r'''
        #include <spdlog/spdlog.h>

        int main() {
            spdlog::info("I am a very simple log message!");
        }
    ''')
    proj.configure()
    proj.build()
