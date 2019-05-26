#!/usr/bin/env python3

import os
import sys
import yaml

CONAN_USER_HOME = os.environ['CONAN_USER_HOME']
CONAN_SETTING = sys.argv[1]

with open(os.path.join(CONAN_USER_HOME, 'settings.yml'), 'r') as settings:
    setting = yaml.load(settings)[CONAN_SETTING]
    print(';'.join(setting))
