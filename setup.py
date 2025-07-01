from setuptools import setup, find_packages

setup(
    # Package name used for installation via pip
    name='python_logging_framework',

    # Version of the package (update with each release)
    version='0.1.0',

    # Short description of the package
    description='Cross-platform logging framework for Python, PowerShell, and Batch script integrations',

    # Author metadata (optional but useful)
    author='Manoj Bhaskaran',

    # Find all packages inside src/common/ directory
    # For example, src/common/python_logging_framework will be imported as 'python_logging_framework'
    packages=find_packages(where='src/common'),

    # Specify that packages are under src/common, not the default current directory
    package_dir={'': 'src/common'},

    # Include non-code files if any are specified using MANIFEST.in (not needed if pure Python)
    include_package_data=True,

    # List runtime dependencies (e.g. if your module uses `colorlog`, `python-json-logger`, etc.)
    install_requires=[
        # e.g. 'colorlog>=6.7.0'
    ],

    # Metadata for PyPI or internal documentation
    classifiers=[
        'Programming Language :: Python :: 3',
        'Operating System :: OS Independent',
        'Intended Audience :: Developers',
        'Topic :: Software Development :: Libraries :: Python Modules',
    ],

    # Minimum required Python version
    python_requires='>=3.7',
)
