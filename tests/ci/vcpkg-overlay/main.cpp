#include <nlohmann/json.hpp>

int main() { auto array = nlohmann::json::parse("[1, 2, 3]"); }