import conans

class PMM(conans.ConanFile):
    name = 'pmm'
    version = '1.0.0'
    settings = None
    exports_sources = '*'
    generators = 'cmake'

    def build(self):
        cmake = conans.CMake(self)
        cmake.configure()
        cmake.build()
