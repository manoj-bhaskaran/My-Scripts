from setuptools import setup
from pathlib import Path


def get_version():
    """Read version from VERSION file."""
    return Path("VERSION").read_text().strip()


setup(
    # Package name used for installation via pip
    name="my-scripts-logging",
    # Version of the package (read from VERSION file)
    version=get_version(),
    # Short description of the package
    description="Cross-platform structured logging framework for Python, PowerShell, and Batch script integrations",
    # Author metadata
    author="Manoj Bhaskaran",
    author_email="",
    # License
    license="Apache-2.0",
    # Single module installation
    py_modules=["python_logging_framework"],
    # Specify that modules are under src/python/modules/logging
    package_dir={"": "src/python/modules/logging"},
    # Runtime dependencies
    install_requires=[
        # zoneinfo is built-in from Python 3.9+
    ],
    # Metadata for PyPI or internal documentation
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: Apache Software License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: 3.13",
        "Programming Language :: Python :: 3.14",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Logging",
    ],
    # Minimum required Python version (PEP 604 union types require 3.10+)
    python_requires=">=3.10",
    # Project URLs
    project_urls={
        "Source": "https://github.com/manoj-bhaskaran/My-Scripts",
    },
)
