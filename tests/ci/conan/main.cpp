#include <spdlog/spdlog.h>

int main() {
    auto console = spdlog::stdout_color_mt("console");
    console->info("Hello!");
}