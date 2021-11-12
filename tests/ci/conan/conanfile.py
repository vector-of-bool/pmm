import conans


class CITestConanProject(conans.ConanFile):
    name = 'CITestProject'
    version = '1.2.3'
    generators = 'cmake'
    requires = ('spdlog/1.4.2')
