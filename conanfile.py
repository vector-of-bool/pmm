import conans

class PMM(conans.ConanFile):
    name = 'pmm'
    version = '1.3.1'
    settings = None
    exports_sources = '*'
    generators = 'cmake'
    # build_requires = (
    #     'libman-generator/[*]@vector-of-bool/test'
    # )
    # generators = 'cmake', 'LibMan'

    def build(self):
        cmake = conans.CMake(self)
        cmake.configure()
        cmake.build()
